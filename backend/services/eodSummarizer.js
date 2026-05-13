const { GoogleGenerativeAI } = require('@google/generative-ai');
const puppeteer = require('puppeteer');
const cloudinary = require('cloudinary').v2;
const axios = require('axios');
const Message = require('../models/Message');
const Channel = require('../models/Channel');
const User = require('../models/User');
const { getScheduledChannelMembers } = require('./trackioService');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const model = genAI.getGenerativeModel({
  model: 'gemini-2.0-flash',
  generationConfig: {
    temperature: 0.3,
    responseMimeType: 'application/json',
  },
});

const GHL_WEBHOOK_URL = process.env.GHL_EOD_WEBHOOK_URL || '';

function getDayBoundaries(date, timezone = 'Asia/Manila') {
  const d = new Date(date);
  const tzOffsetMs = 8 * 60 * 60 * 1000;

  const manilaDate = new Date(d.getTime() + tzOffsetMs);
  const year = manilaDate.getUTCFullYear();
  const month = manilaDate.getUTCMonth();
  const day = manilaDate.getUTCDate();

  const startUTC = new Date(Date.UTC(year, month, day, 0, 0, 0) - tzOffsetMs);
  const endUTC = new Date(Date.UTC(year, month, day, 23, 59, 59, 999) - tzOffsetMs);

  const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;

  return { startUTC, endUTC, dateStr };
}

function formatDisplayDate(dateStr) {
  const [year, month, day] = dateStr.split('-').map(Number);
  const d = new Date(year, month - 1, day);
  return d.toLocaleDateString('en-US', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });
}

async function summarizeIndividualEod(personName, combinedText) {
  const prompt = `You are summarizing an End-of-Day report from a team member at Telex Business Support Services Inc.

Team Member: ${personName}

Their raw EOD message(s) for today:
---
${combinedText}
---

Generate a structured summary in valid JSON format with these exact keys:
{
  "summary": "2-3 sentence executive summary of what they accomplished",
  "keyItems": ["bullet point 1", "bullet point 2"],
  "blockers": ["blocker 1"],
  "tomorrow": ["priority 1"]
}

Rules:
- Be concise and professional
- Extract specific accomplishments, projects, and tasks mentioned
- If something is unclear, do not invent details
- If they did not mention blockers, return empty array
- If they did not mention tomorrow's plan, return empty array
- Output ONLY valid JSON`;

  try {
    const result = await model.generateContent(prompt);
    const text = result.response.text().trim();
    const cleaned = text.replace(/^```json\s*/, '').replace(/\s*```$/, '');
    return JSON.parse(cleaned);
  } catch (err) {
    console.error(`❌ Gemini error for ${personName}:`, err.message);
    return {
      summary: combinedText.substring(0, 200) + (combinedText.length > 200 ? '...' : ''),
      keyItems: [],
      blockers: [],
      tomorrow: [],
    };
  }
}

async function generateExecutiveSummary(individualSummaries, teamName) {
  const allSummaries = individualSummaries
    .map((s) => `- ${s.name}: ${s.summary}`)
    .join('\n');

  const prompt = `Based on these individual EOD summaries from the ${teamName} team at Telex Business Support Services Inc.:

${allSummaries}

Write a 2-3 sentence executive overview of today's team activity. Focus on key wins, themes, and productivity.

Output ONLY valid JSON in this format:
{
  "overview": "Your 2-3 sentence overview here"
}`;

  try {
    const result = await model.generateContent(prompt);
    const text = result.response.text().trim();
    const cleaned = text.replace(/^```json\s*/, '').replace(/\s*```$/, '');
    const parsed = JSON.parse(cleaned);
    return parsed.overview;
  } catch (err) {
    console.error('❌ Executive summary error:', err.message);
    return `The ${teamName} team submitted ${individualSummaries.length} EOD report(s) today.`;
  }
}

function buildPdfHtml({
  teamName,
  displayDate,
  submittedCount,
  expectedCount,
  executiveSummary,
  individualSummaries,
  missingMembers,
}) {
  const sections = individualSummaries
    .map((s) => {
      const initial = s.name.charAt(0).toUpperCase();
      const time = new Date(s.submittedAt).toLocaleTimeString('en-US', {
        hour: 'numeric',
        minute: '2-digit',
        hour12: true,
        timeZone: 'Asia/Manila',
      });

      const keyItemsHtml =
        s.keyItems.length > 0
          ? `<div class="section"><div class="section-title">Key Items</div><ul>${s.keyItems.map((i) => `<li>${escapeHtml(i)}</li>`).join('')}</ul></div>`
          : '';

      const blockersHtml =
        s.blockers.length > 0
          ? `<div class="section"><div class="section-title">Blockers</div><ul>${s.blockers.map((i) => `<li>${escapeHtml(i)}</li>`).join('')}</ul></div>`
          : '';

      const tomorrowHtml =
        s.tomorrow.length > 0
          ? `<div class="section"><div class="section-title">Tomorrow's Priorities</div><ul>${s.tomorrow.map((i) => `<li>${escapeHtml(i)}</li>`).join('')}</ul></div>`
          : '';

      return `
        <div class="person-card">
          <div class="person-header">
            <div class="avatar">${initial}</div>
            <div>
              <div class="person-name">${escapeHtml(s.name)}</div>
              <div class="person-meta">Submitted at ${time}</div>
            </div>
          </div>
          <div class="person-summary">${escapeHtml(s.summary)}</div>
          ${keyItemsHtml}
          ${blockersHtml}
          ${tomorrowHtml}
        </div>
      `;
    })
    .join('');

  const missingHtml =
    missingMembers.length > 0
      ? `<div class="missing-section">
          <div class="missing-title">⚠️ Did Not Submit (Scheduled for Today)</div>
          <ul>${missingMembers.map((m) => `<li>${escapeHtml(m.name)}</li>`).join('')}</ul>
        </div>`
      : '';

  return `<!DOCTYPE html>
<html><head><meta charset="UTF-8"><style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: 'Segoe UI', Arial, sans-serif; color: #202020; background: #fff; padding: 40px; font-size: 13px; line-height: 1.5; }
  .header { border-bottom: 3px solid #A10000; padding-bottom: 20px; margin-bottom: 30px; }
  .company { font-size: 11px; color: #8A8A8F; letter-spacing: 1.5px; font-weight: 600; text-transform: uppercase; }
  .title { font-size: 28px; font-weight: 900; color: #A10000; margin: 6px 0; }
  .meta { color: #5a5a5a; font-size: 13px; margin-top: 8px; }
  .meta strong { color: #202020; }
  .exec-summary { background: #FBEAEA; border-left: 4px solid #A10000; padding: 18px 22px; border-radius: 8px; margin-bottom: 30px; }
  .exec-title { font-size: 11px; font-weight: 800; color: #A10000; letter-spacing: 1.2px; margin-bottom: 8px; }
  .exec-text { color: #202020; line-height: 1.6; font-size: 13.5px; }
  .divider { border-top: 2px solid #E9E9ED; margin: 30px 0 20px; padding-top: 14px; font-size: 11px; color: #8A8A8F; letter-spacing: 1.2px; font-weight: 800; }
  .person-card { background: #fff; border: 1px solid #E9E9ED; border-radius: 12px; padding: 20px 22px; margin-bottom: 16px; page-break-inside: avoid; }
  .person-header { display: flex; align-items: center; gap: 12px; margin-bottom: 12px; padding-bottom: 12px; border-bottom: 1px solid #F1F1F4; }
  .avatar { width: 38px; height: 38px; border-radius: 50%; background: linear-gradient(135deg, #650000, #A10000); color: white; display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 16px; }
  .person-name { font-size: 15px; font-weight: 800; color: #202020; }
  .person-meta { color: #8A8A8F; font-size: 11px; }
  .person-summary { color: #202020; line-height: 1.55; margin-bottom: 12px; }
  .section { margin-top: 10px; }
  .section-title { font-size: 10.5px; font-weight: 800; color: #A10000; letter-spacing: 0.8px; text-transform: uppercase; margin-bottom: 5px; }
  ul { margin-left: 18px; color: #303030; }
  ul li { margin-bottom: 3px; line-height: 1.5; }
  .missing-section { background: #FFF8E5; border-left: 4px solid #F0B400; padding: 14px 18px; border-radius: 8px; margin-top: 20px; }
  .missing-title { font-weight: 800; color: #8A6700; margin-bottom: 6px; font-size: 12px; }
  .footer { margin-top: 40px; padding-top: 18px; border-top: 1px solid #E9E9ED; color: #8A8A8F; font-size: 10.5px; text-align: center; }
</style></head><body>
  <div class="header">
    <div class="company">Telex Business Support Services Inc.</div>
    <div class="title">End-of-Day Report</div>
    <div class="meta">
      <strong>Team:</strong> ${escapeHtml(teamName)}<br>
      <strong>Date:</strong> ${displayDate}<br>
      <strong>Submissions:</strong> ${submittedCount} of ${expectedCount} scheduled members
    </div>
  </div>
  <div class="exec-summary">
    <div class="exec-title">EXECUTIVE OVERVIEW</div>
    <div class="exec-text">${escapeHtml(executiveSummary)}</div>
  </div>
  <div class="divider">INDIVIDUAL EOD REPORTS</div>
  ${sections}
  ${missingHtml}
  <div class="footer">Generated by TxHive · ${new Date().toLocaleString('en-US', { timeZone: 'Asia/Manila' })} (Manila Time) · Schedule data from Trackio</div>
</body></html>`;
}

function escapeHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

async function generatePdfBuffer(html) {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });
  try {
    const page = await browser.newPage();
    await page.setContent(html, { waitUntil: 'networkidle0' });
    const buffer = await page.pdf({
      format: 'A4',
      printBackground: true,
      margin: { top: '20mm', right: '15mm', bottom: '20mm', left: '15mm' },
    });
    return buffer;
  } finally {
    await browser.close();
  }
}

async function uploadPdfToCloudinary(buffer, filename) {
  return new Promise((resolve, reject) => {
    cloudinary.uploader
      .upload_stream(
        { resource_type: 'raw', folder: 'txhive-eod', public_id: filename, format: 'pdf' },
        (err, result) => {
          if (err) return reject(err);
          resolve(result.secure_url);
        }
      )
      .end(buffer);
  });
}

/**
 * Main entry: generate full EOD summary using Trackio for expected list
 */
async function generateEodSummary({ channelId, date = new Date(), force = false }) {
  const channel = await Channel.findById(channelId);
  if (!channel) throw new Error('Channel not found');
  if (!channel.isEodChannel) throw new Error('Channel is not configured as an EOD channel');

  const { startUTC, endUTC, dateStr } = getDayBoundaries(date, channel.eodConfig.timezone);

  if (!force && channel.eodConfig.lastSummaryDate === dateStr) {
    return { skipped: true, reason: 'Already generated today' };
  }

  // 🔗 Get scheduled members from Trackio (cross-referenced with channel members)
  const scheduledUsers = await getScheduledChannelMembers(channel, User, date);
  console.log(
    `📅 ${scheduledUsers.length} member(s) scheduled for ${dateStr} in #${channel.name}`
  );

  if (scheduledUsers.length === 0) {
    return { skipped: true, reason: 'No scheduled members today (per Trackio)' };
  }

  // Get messages for the day
  const messages = await Message.find({
    channel: channel._id,
    createdAt: { $gte: startUTC, $lte: endUTC },
    deleted: false,
  })
    .populate('sender', 'name email')
    .sort({ createdAt: 1 });

  if (messages.length === 0) {
    return { skipped: true, reason: 'No EOD messages submitted today' };
  }

  // Group by sender
  const bySender = new Map();
  for (const m of messages) {
    const senderId = m.sender._id.toString();
    if (!bySender.has(senderId)) {
      bySender.set(senderId, {
        senderId,
        name: m.sender.name,
        email: m.sender.email,
        messages: [],
        firstSubmittedAt: m.createdAt,
      });
    }
    bySender.get(senderId).messages.push(m.content);
  }

  console.log(`📝 Summarizing ${bySender.size} EOD report(s) via Gemini API...`);
  const individualSummaries = [];
  for (const [, person] of bySender) {
    const combined = person.messages.join('\n\n');
    const ai = await summarizeIndividualEod(person.name, combined);
    individualSummaries.push({
      name: person.name,
      email: person.email,
      submittedAt: person.firstSubmittedAt,
      summary: ai.summary,
      keyItems: ai.keyItems || [],
      blockers: ai.blockers || [],
      tomorrow: ai.tomorrow || [],
    });
    await new Promise((r) => setTimeout(r, 500));
  }

  // Determine missing members (scheduled but did not submit)
  const submittedIds = new Set(bySender.keys());
  const missingMembers = scheduledUsers
    .filter((u) => !submittedIds.has(u._id.toString()))
    .map((u) => ({ name: u.name, email: u.email }));

  console.log(`📝 Generating executive overview...`);
  const executiveSummary = await generateExecutiveSummary(individualSummaries, channel.name);

  console.log(`📄 Generating PDF...`);
  const displayDate = formatDisplayDate(dateStr);
  const html = buildPdfHtml({
    teamName: channel.name,
    displayDate,
    submittedCount: individualSummaries.length,
    expectedCount: scheduledUsers.length,
    executiveSummary,
    individualSummaries,
    missingMembers,
  });

  const pdfBuffer = await generatePdfBuffer(html);
  const filename = `eod-${channel.name}-${dateStr}-${Date.now()}`;
  const pdfUrl = await uploadPdfToCloudinary(pdfBuffer, filename);

  console.log(`✅ PDF uploaded: ${pdfUrl}`);

  // POST to GHL webhook (from .env)
  if (GHL_WEBHOOK_URL) {
    try {
      await axios.post(
        GHL_WEBHOOK_URL,
        {
          date: dateStr,
          displayDate,
          teamName: channel.name,
          channelId: channel._id.toString(),
          submitterCount: individualSummaries.length,
          expectedCount: scheduledUsers.length,
          missingMembers,
          recipientEmails: channel.eodConfig.summaryRecipientEmails,
          executiveSummary,
          individualSummaries,
          pdfUrl,
        },
        { timeout: 15000 }
      );
      console.log(`📤 Sent to GHL webhook successfully`);
    } catch (err) {
      console.error(`❌ GHL webhook error:`, err.message);
    }
  } else {
    console.warn('⚠️ GHL_EOD_WEBHOOK_URL not set in .env');
  }

  channel.eodConfig.lastSummaryDate = dateStr;
  await channel.save();

  return {
    success: true,
    pdfUrl,
    date: dateStr,
    submitterCount: individualSummaries.length,
    expectedCount: scheduledUsers.length,
    scheduledMembers: scheduledUsers.map((u) => ({ name: u.name, email: u.email })),
    missingMembers,
  };
}

/**
 * Auto-trigger check: if all SCHEDULED members have submitted, generate summary
 */
async function checkAndTriggerEod(channelId) {
  const channel = await Channel.findById(channelId);
  if (!channel || !channel.isEodChannel || !channel.eodConfig.autoSendOnComplete) return;

  const { startUTC, endUTC, dateStr } = getDayBoundaries(new Date(), channel.eodConfig.timezone);
  if (channel.eodConfig.lastSummaryDate === dateStr) return;

  // Get who's scheduled today (from Trackio)
  const scheduledUsers = await getScheduledChannelMembers(channel, User, new Date());
  if (scheduledUsers.length === 0) return; // No one scheduled today

  // Get who submitted today
  const submitters = await Message.distinct('sender', {
    channel: channel._id,
    createdAt: { $gte: startUTC, $lte: endUTC },
    deleted: false,
  });

  const scheduledIds = new Set(scheduledUsers.map((u) => u._id.toString()));
  const submittedIds = new Set(submitters.map((id) => id.toString()));

  const allSubmitted = [...scheduledIds].every((id) => submittedIds.has(id));

  if (allSubmitted) {
    console.log(
      `🎯 All ${scheduledUsers.length} scheduled member(s) submitted in #${channel.name} — triggering summary`
    );
    try {
      await generateEodSummary({ channelId: channel._id });
    } catch (err) {
      console.error('❌ Auto-trigger error:', err.message);
    }
  } else {
    console.log(
      `⏳ #${channel.name}: ${submittedIds.size}/${scheduledIds.size} submitted, waiting...`
    );
  }
}

module.exports = {
  generateEodSummary,
  checkAndTriggerEod,
  getDayBoundaries,
};