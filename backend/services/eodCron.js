const cron = require('node-cron');
const Channel = require('../models/Channel');
const { generateEodSummary, getDayBoundaries } = require('./eodSummarizer');

/**
 * Runs every 10 minutes — checks if any EOD channel has reached cutoff time
 * and sends summary with whoever submitted (fallback behavior).
 */
function startEodCronJobs() {
  cron.schedule('*/10 * * * *', async () => {
    try {
      const eodChannels = await Channel.find({ isEodChannel: true });
      if (eodChannels.length === 0) return;

      // Current time in Manila
      const nowUtc = new Date();
      const nowManila = new Date(nowUtc.getTime() + 8 * 60 * 60 * 1000);
      const nowHHmm = `${String(nowManila.getUTCHours()).padStart(2, '0')}:${String(
        nowManila.getUTCMinutes()
      ).padStart(2, '0')}`;

      for (const channel of eodChannels) {
        const cutoff = channel.eodConfig.cutoffTime || '19:00';
        const { dateStr } = getDayBoundaries(nowUtc, channel.eodConfig.timezone);

        // Already sent today? skip
        if (channel.eodConfig.lastSummaryDate === dateStr) continue;

        // Past cutoff time?
        if (nowHHmm >= cutoff) {
          console.log(
            `⏰ Cutoff reached for #${channel.name} (${cutoff}) — generating EOD summary`
          );
          try {
            await generateEodSummary({ channelId: channel._id, date: nowUtc });
          } catch (err) {
            console.error(`❌ Cron EOD error for ${channel.name}:`, err.message);
          }
        }
      }
    } catch (err) {
      console.error('❌ EOD cron error:', err.message);
    }
  });

  console.log('⏱️  EOD cron scheduler started (runs every 10 minutes)');
}

module.exports = { startEodCronJobs };