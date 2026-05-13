const { GoogleGenerativeAI } = require('@google/generative-ai');
const puppeteer = require('puppeteer');
const cloudinary = require('cloudinary').v2;
const axios = require('axios');
const Message = require('../models/Message');
const Channel = require('../models/Channel');
const User = require('../models/User');
const { getScheduledChannelMembers } = require('./trackioService');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
// ✅ Updated to gemini-2.5-flash (2.0-flash deprecated March 2026)
const model = genAI.getGenerativeModel({
  model: 'gemini-2.5-flash',
  generationConfig: {
    temperature: 0.2,
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

/**
 * Wrapper with rate-limit aware retry
 * Gemini 2.5 Flash free tier: 10 RPM, 500 RPD
 */
async function callGeminiWithRetry(prompt, maxRetries = 3) {
  let lastError;
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const result = await model.generateContent(prompt);
      return result.response.text().trim();
    } catch (err) {
      lastError = err;
      const isRateLimit = err.message?.includes('429') || err.message?.includes('Too Many Requests');
      if (!isRateLimit || attempt === maxRetries - 1) throw err;

      // Extract retry delay from error message, or default to exponential backoff
      const retryMatch = err.message.match(/retry in ([\d.]+)s/);
      const waitSec = retryMatch ? Math.ceil(parseFloat(retryMatch[1])) + 2 : (attempt + 1) * 15;

      console.log(`⏳ Rate limit hit. Waiting ${waitSec}s before retry ${attempt + 1}/${maxRetries}...`);
      await new Promise((r) => setTimeout(r, waitSec * 1000));
    }
  }
  throw lastError;
}

/**
 * Parse a person's raw EOD into project-grouped structure
 */
async function parseEodIntoProjects(personName, combinedText) {
  const prompt = `You are an expert EOD report parser for the Innovation Department of Telex Business Support Services Inc.

Team Member: ${personName}

Their raw EOD message(s) for today (may include multiple sends throughout the day):
---
${combinedText}
---

The EOD typically follows this structure (but may vary in formatting):
- Tasks grouped by project/initiative (e.g., "Messaging App", "WanderWave", "HaidoVille", "TexionixBug Reporter")
- Each project has: Done items and Pending items
- There may be additional tasks not tied to a specific project

Your job: Extract and organize their work into JSON with this EXACT structure:
{
  "projects": [
    {
      "name": "Project name as mentioned (e.g., 'Messaging App (TxHive)')",
      "done": ["specific accomplishment 1", "specific accomplishment 2"],
      "pending": ["pending item 1", "pending item 2"]
    }
  ],
  "additionalTasks": ["task not tied to a project 1", "task 2"],
  "hasContent": true
}

CRITICAL RULES:
- Preserve the team member's actual project names (don't rename)
- Extract SPECIFIC, concrete items — NEVER generic phrases like "worked on X"
- Each bullet should be a complete, standalone statement (not a fragment)
- If a project has only done items and no pending, return empty array for pending (and vice versa)
- "additionalTasks" is for meetings, reviews, admin work, or anything NOT under a specific project
- If the EOD message is unclear, malformed, or just a casual chat (not an actual EOD), set "hasContent": false and return empty arrays
- DO NOT invent or pad content. If they only said 2 things, only output 2 things.
- DO NOT lose information. Every specific task/item mentioned must appear somewhere in the output.
- Preserve technical terminology, project names, and proper nouns exactly as written
- Output ONLY valid JSON, no markdown`;

  try {
    const text = await callGeminiWithRetry(prompt);
    const cleaned = text.replace(/^```json\s*/, '').replace(/\s*```$/, '');
    const parsed = JSON.parse(cleaned);

    return {
      projects: Array.isArray(parsed.projects) ? parsed.projects : [],
      additionalTasks: Array.isArray(parsed.additionalTasks) ? parsed.additionalTasks : [],
      hasContent: parsed.hasContent !== false,
    };
  } catch (err) {
    console.error(`❌ Gemini parse error for ${personName}:`, err.message);
    return {
      projects: [],
      additionalTasks: [],
      hasContent: false,
      raw: combinedText.substring(0, 500),
    };
  }
}

/**
 * Generate executive overview from all individual project breakdowns
 */
async function generateExecutiveSummary(individualSummaries, teamName) {
  const consolidated = individualSummaries
    .map((s) => {
      const lines = [`${s.name}:`];
      s.projects.forEach((p) => {
        if (p.done && p.done.length > 0) {
          lines.push(`  ${p.name}: ${p.done.join('; ')}`);
        }
      });
      if (s.additionalTasks && s.additionalTasks.length > 0) {
        lines.push(`  Other: ${s.additionalTasks.join('; ')}`);
      }
      return lines.join('\n');
    })
    .join('\n\n');

  const prompt = `Based on today's accomplishments from the ${teamName} team at Telex Business Support Services Inc.:

${consolidated}

Write a 3-4 sentence executive overview that:
1. Highlights the most significant team-wide accomplishments
2. Identifies any common themes or projects that received major attention
3. Mentions notable individual contributions if relevant
4. Maintains a professional, leadership-focused tone (this is for department heads)

Output ONLY valid JSON: {"overview": "your 3-4 sentence overview"}`;

  try {
    const text = await callGeminiWithRetry(prompt);
    const cleaned = text.replace(/^```json\s*/, '').replace(/\s*```$/, '');
    const parsed = JSON.parse(cleaned);
    return parsed.overview;
  } catch (err) {
    console.error('❌ Executive summary error:', err.message);
    return `The ${teamName} team submitted ${individualSummaries.length} EOD report(s) today.`;
  }
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

function buildPdfHtml({
  teamName,
  displayDate,
  submittedCount,
  expectedCount,
  executiveSummary,
  individualSummaries,
  missingMembers,
}) {
  const personSections = individualSummaries
    .map((s) => {
      const initial = s.name.charAt(0).toUpperCase();
      const time = new Date(s.submittedAt).toLocaleTimeString('en-US', {
        hour: 'numeric',
        minute: '2-digit',
        hour12: true,
        timeZone: 'Asia/Manila',
      });

      const projectsHtml =
        s.projects.length > 0
          ? s.projects
              .map((p) => {
                const doneList =
                  p.done && p.done.length > 0
                    ? `<div class="task-block">
                        <div class="task-label done-label">✓ Done</div>
                        <ul class="done-list">${p.done.map((i) => `<li>${escapeHtml(i)}</li>`).join('')}</ul>
                      </div>`
                    : '';
                const pendingList =
                  p.pending && p.pending.length > 0
                    ? `<div class="task-block">
                        <div class="task-label pending-label">⏳ Pending</div>
                        <ul class="pending-list">${p.pending.map((i) => `<li>${escapeHtml(i)}</li>`).join('')}</ul>
                      </div>`
                    : '';
                return `
                  <div class="project-card">
                    <div class="project-name">📌 ${escapeHtml(p.name)}</div>
                    ${doneList}
                    ${pendingList}
                  </div>
                `;
              })
              .join('')
          : '';

      const additionalHtml =
        s.additionalTasks && s.additionalTasks.length > 0
          ? `<div class="project-card additional">
              <div class="project-name">📋 Additional Tasks</div>
              <ul class="other-list">${s.additionalTasks.map((i) => `<li>${escapeHtml(i)}</li>`).join('')}</ul>
            </div>`
          : '';

      const noContentNotice =
        !s.hasContent
          ? `<div class="warning-block">⚠️ Unable to parse structured EOD content. Raw message:<br><em>${escapeHtml(s.raw || '')}</em></div>`
          : '';

      return `
        <div class="person-section">
          <div class="person-header">
            <div class="avatar">${initial}</div>
            <div class="person-info">
              <div class="person-name">${escapeHtml(s.name)}</div>
              <div class="person-meta">Submitted at ${time}</div>
            </div>
          </div>
          ${noContentNotice}
          ${projectsHtml}
          ${additionalHtml}
          ${
            s.projects.length === 0 && (!s.additionalTasks || s.additionalTasks.length === 0) && s.hasContent
              ? '<div class="empty-notice">No specific tasks or projects extracted.</div>'
              : ''
          }
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
  body { font-family: 'Segoe UI', Arial, sans-serif; color: #202020; background: #fff; padding: 40px; font-size: 12.5px; line-height: 1.5; }
  .header { border-bottom: 3px solid #A10000; padding-bottom: 20px; margin-bottom: 26px; }
  .company { font-size: 11px; color: #8A8A8F; letter-spacing: 1.5px; font-weight: 600; text-transform: uppercase; }
  .title { font-size: 28px; font-weight: 900; color: #A10000; margin: 6px 0; }
  .meta { color: #5a5a5a; font-size: 12.5px; margin-top: 8px; }
  .meta strong { color: #202020; }
  .exec-summary { background: #FBEAEA; border-left: 4px solid #A10000; padding: 16px 20px; border-radius: 8px; margin-bottom: 24px; }
  .exec-title { font-size: 11px; font-weight: 800; color: #A10000; letter-spacing: 1.2px; margin-bottom: 8px; }
  .exec-text { color: #202020; line-height: 1.6; font-size: 13px; }
  .divider { border-top: 2px solid #E9E9ED; margin: 26px 0 18px; padding-top: 12px; font-size: 11px; color: #8A8A8F; letter-spacing: 1.2px; font-weight: 800; }
  .person-section { margin-bottom: 22px; page-break-inside: avoid; }
  .person-header { display: flex; align-items: center; gap: 12px; margin-bottom: 12px; padding-bottom: 10px; border-bottom: 2px solid #F1F1F4; }
  .avatar { width: 36px; height: 36px; border-radius: 50%; background: linear-gradient(135deg, #650000, #A10000); color: white; display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 15px; flex-shrink: 0; }
  .person-info { flex: 1; }
  .person-name { font-size: 16px; font-weight: 900; color: #202020; }
  .person-meta { color: #8A8A8F; font-size: 10.5px; margin-top: 2px; }
  .project-card { background: #FAFAFC; border: 1px solid #E9E9ED; border-radius: 10px; padding: 12px 16px; margin-bottom: 10px; page-break-inside: avoid; }
  .project-card.additional { background: #FFF8E5; border-color: #F0D88A; }
  .project-name { font-size: 13px; font-weight: 800; color: #650000; margin-bottom: 8px; }
  .additional .project-name { color: #8A6700; }
  .task-block { margin-top: 6px; }
  .task-label { font-size: 10px; font-weight: 800; letter-spacing: 0.6px; text-transform: uppercase; margin-bottom: 3px; }
  .done-label { color: #1F7A1F; }
  .pending-label { color: #C25F00; }
  ul { margin-left: 18px; color: #303030; font-size: 12.5px; }
  ul li { margin-bottom: 3px; line-height: 1.5; }
  .done-list li::marker { color: #1F7A1F; }
  .pending-list li::marker { color: #C25F00; }
  .other-list li::marker { color: #8A6700; }
  .empty-notice { color: #8A8A8F; font-style: italic; font-size: 12px; padding: 8px 12px; }
  .warning-block { background: #FFE5E5; border: 1px solid #F2CACA; border-radius: 6px; padding: 10px 12px; font-size: 11.5px; color: #8A2929; margin-bottom: 10px; }
  .missing-section { background: #FFF8E5; border-left: 4px solid #F0B400; padding: 12px 16px; border-radius: 8px; margin-top: 20px; }
  .missing-title { font-weight: 800; color: #8A6700; margin-bottom: 6px; font-size: 12px; }
  .footer { margin-top: 36px; padding-top: 16px; border-top: 1px solid #E9E9ED; color: #8A8A8F; font-size: 10.5px; text-align: center; }
</style></head><body>
  <div class="header">
    <div class="company">Telex Business Support Services Inc. · Innovation Department</div>
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
  ${personSections}
  ${missingHtml}
  <div class="footer">Generated by TxHive · ${new Date().toLocaleString('en-US', { timeZone: 'Asia/Manila' })} (Manila Time) · Schedule data from Trackio</div>
</body></html>`;
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

async function generateEodSummary({ channelId, date = new Date(), force = false }) {
  const channel = await Channel.findById(channelId);
  if (!channel) throw new Error('Channel not found');
  if (!channel.isEodChannel) throw new Error('Channel is not configured as an EOD channel');

  const { startUTC, endUTC, dateStr } = getDayBoundaries(date, channel.eodConfig.timezone);

  if (!force && channel.eodConfig.lastSummaryDate === dateStr) {
    return { skipped: true, reason: 'Already generated today' };
  }

  const scheduledUsers = await getScheduledChannelMembers(channel, User, date);
  console.log(`📅 ${scheduledUsers.length} member(s) scheduled for ${dateStr} in #${channel.name}`);

  if (scheduledUsers.length === 0) {
    return { skipped: true, reason: 'No scheduled members today (per Trackio)' };
  }

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

  console.log(`📝 Parsing ${bySender.size} EOD report(s) into project structure...`);
  const individualSummaries = [];
  let isFirstCall = true;
  for (const [, person] of bySender) {
    // ✅ Stagger calls — 7 seconds between each to stay under 10 RPM safely
    if (!isFirstCall) {
      console.log('⏱️  Waiting 7s before next Gemini call (rate limit safety)...');
      await new Promise((r) => setTimeout(r, 7000));
    }
    isFirstCall = false;

    const combined = person.messages.join('\n\n');
    const parsed = await parseEodIntoProjects(person.name, combined);
    individualSummaries.push({
      name: person.name,
      email: person.email,
      submittedAt: person.firstSubmittedAt,
      projects: parsed.projects,
      additionalTasks: parsed.additionalTasks,
      hasContent: parsed.hasContent,
      raw: parsed.raw,
    });
  }

  const submittedIds = new Set(bySender.keys());
  const missingMembers = scheduledUsers
    .filter((u) => !submittedIds.has(u._id.toString()))
    .map((u) => ({ name: u.name, email: u.email }));

  console.log('⏱️  Waiting 7s before executive summary call...');
  await new Promise((r) => setTimeout(r, 7000));

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

async function checkAndTriggerEod(channelId) {
  const channel = await Channel.findById(channelId);
  if (!channel || !channel.isEodChannel || !channel.eodConfig.autoSendOnComplete) return;

  const { startUTC, endUTC, dateStr } = getDayBoundaries(new Date(), channel.eodConfig.timezone);
  if (channel.eodConfig.lastSummaryDate === dateStr) return;

  const scheduledUsers = await getScheduledChannelMembers(channel, User, new Date());
  if (scheduledUsers.length === 0) return;

  const submitters = await Message.distinct('sender', {
    channel: channel._id,
    createdAt: { $gte: startUTC, $lte: endUTC },
    deleted: false,
  });

  const scheduledIds = new Set(scheduledUsers.map((u) => u._id.toString()));
  const submittedIds = new Set(submitters.map((id) => id.toString()));

  const allSubmitted = [...scheduledIds].every((id) => submittedIds.has(id));

  if (allSubmitted) {
    console.log(`🎯 All ${scheduledUsers.length} scheduled member(s) submitted in #${channel.name} — triggering summary`);
    try {
      await generateEodSummary({ channelId: channel._id });
    } catch (err) {
      console.error('❌ Auto-trigger error:', err.message);
    }
  } else {
    console.log(`⏳ #${channel.name}: ${submittedIds.size}/${scheduledIds.size} submitted, waiting...`);
  }
}

module.exports = {
  generateEodSummary,
  checkAndTriggerEod,
  getDayBoundaries,
};