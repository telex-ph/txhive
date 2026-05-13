const axios = require('axios');

const TRACKIO_URL =
  process.env.TRACKIO_API_URL ||
  'https://trackio-backend-xprm.onrender.com/schedules/trackioSchedule';

const TRACKIO_TOKEN = process.env.TRACKIO_API_TOKEN || '';

/**
 * Format date as YYYY-MM-DD (for request body)
 */
function toYmd(date) {
  const tzOffsetMs = 8 * 60 * 60 * 1000;
  const manilaDate = new Date(date.getTime() + tzOffsetMs);
  const y = manilaDate.getUTCFullYear();
  const m = String(manilaDate.getUTCMonth() + 1).padStart(2, '0');
  const d = String(manilaDate.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/**
 * Convert Date to MM-DD-YYYY string (Trackio shiftDate format) in Manila TZ
 */
function dateToTrackioFormat(date = new Date()) {
  const tzOffsetMs = 8 * 60 * 60 * 1000;
  const manilaDate = new Date(date.getTime() + tzOffsetMs);
  const month = String(manilaDate.getUTCMonth() + 1).padStart(2, '0');
  const day = String(manilaDate.getUTCDate()).padStart(2, '0');
  const year = manilaDate.getUTCFullYear();
  return `${month}-${day}-${year}`;
}

/**
 * Fetch employee schedules from Trackio for a date range (POST request)
 */
async function fetchSchedules(startDate, endDate) {
  try {
    const res = await axios.post(
      TRACKIO_URL,
      {
        startDate: toYmd(startDate),
        endDate: toYmd(endDate),
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'x-wall-token': TRACKIO_TOKEN,
        },
        timeout: 15000,
      }
    );

    if (!Array.isArray(res.data)) {
      console.error('❌ Trackio: unexpected response format', typeof res.data);
      return [];
    }
    return res.data;
  } catch (err) {
    console.error(
      `❌ Trackio fetch error: ${err.message}`,
      err.response?.data ? `| ${JSON.stringify(err.response.data)}` : ''
    );
    return [];
  }
}

/**
 * Get employees scheduled to work on a specific date
 */
async function getScheduledEmployees(date = new Date()) {
  const trackioDate = dateToTrackioFormat(date);

  // Fetch a 3-day window around the target date for safety
  const start = new Date(date.getTime() - 2 * 24 * 60 * 60 * 1000);
  const end = new Date(date.getTime() + 2 * 24 * 60 * 60 * 1000);
  const all = await fetchSchedules(start, end);

  const scheduled = [];
  for (const employee of all) {
    if (!employee.schedules || !Array.isArray(employee.schedules)) continue;
    const todayShift = employee.schedules.find((s) => s.shiftDate === trackioDate);
    if (todayShift) {
      scheduled.push({
        fullName: employee.fullName,
        email: (employee.email || '').toLowerCase().trim(),
        shiftStart: todayShift.shiftStart,
        shiftEnd: todayShift.shiftEnd,
      });
    }
  }

  console.log(
    `📅 Trackio: ${scheduled.length} employee(s) scheduled for ${trackioDate}`
  );
  return scheduled;
}

/**
 * Filter scheduled employees to channel members
 */
async function getScheduledChannelMembers(channel, User, date = new Date()) {
  const scheduled = await getScheduledEmployees(date);

  console.log('\n========== EOD DIAGNOSTIC ==========');
  console.log(`📅 Today (Manila): ${dateToTrackioFormat(date)}`);
  console.log(`📋 Scheduled today (from Trackio): ${scheduled.length} people`);
  scheduled.forEach((s) => console.log(`   - ${s.fullName} <${s.email}>`));

  if (scheduled.length === 0) {
    console.log('⚠️ No one scheduled today per Trackio');
    console.log('=====================================\n');
    return [];
  }

  const emails = scheduled.map((s) => s.email);
  const channelMemberIds = (channel.members || []).map((id) => id.toString());

  console.log(`\n📌 Channel members count: ${channelMemberIds.length}`);

  // Case-insensitive email match using regex
  const allMatchingUsers = await User.find({
    email: { $in: emails.map((e) => new RegExp(`^${e.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i')) },
  });

  console.log(`\n🔍 TxHive users matching scheduled emails: ${allMatchingUsers.length}`);
  allMatchingUsers.forEach((u) =>
    console.log(
      `   - ${u.name} <${u.email}> | _id: ${u._id} | inChannel: ${channelMemberIds.includes(u._id.toString())}`
    )
  );

  // Filter to channel members
  const users = allMatchingUsers.filter((u) =>
    channelMemberIds.includes(u._id.toString())
  );

  console.log(`\n✅ Final result (scheduled + channel member): ${users.length}`);
  users.forEach((u) => console.log(`   - ${u.name} <${u.email}>`));
  console.log('=====================================\n');

  return users;
}

module.exports = {
  fetchSchedules,
  getScheduledEmployees,
  getScheduledChannelMembers,
  dateToTrackioFormat,
};