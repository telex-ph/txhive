const express = require('express');
const Channel = require('../models/Channel');
const Workspace = require('../models/Workspace');
const User = require('../models/User');
const { protect } = require('../middleware/auth');
const { generateEodSummary } = require('../services/eodSummarizer');
const { getScheduledChannelMembers } = require('../services/trackioService');

const router = express.Router();

async function isWorkspaceAdmin(channel, userId) {
  if (!channel.workspace) return false;
  const ws = await Workspace.findById(channel.workspace);
  if (!ws) return false;
  const m = ws.members.find((mm) => mm.user.toString() === userId.toString());
  return m && m.role === 'admin';
}

// GET /api/eod/:channelId/config
router.get('/:channelId/config', protect, async (req, res) => {
  try {
    const channel = await Channel.findById(req.params.channelId);
    if (!channel) return res.status(404).json({ message: 'Channel not found' });

    const isMember = channel.members.some((m) => m.toString() === req.user._id.toString());
    if (!isMember) return res.status(403).json({ message: 'Not a member' });

    res.json({
      isEodChannel: channel.isEodChannel,
      eodConfig: channel.eodConfig,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// PUT /api/eod/:channelId/config
router.put('/:channelId/config', protect, async (req, res) => {
  try {
    const channel = await Channel.findById(req.params.channelId);
    if (!channel) return res.status(404).json({ message: 'Channel not found' });

    const isAdmin = await isWorkspaceAdmin(channel, req.user._id);
    if (!isAdmin) return res.status(403).json({ message: 'Only admins can configure EOD' });

    const {
      isEodChannel,
      summaryRecipientEmails,
      cutoffTime,
      timezone,
      autoSendOnComplete,
    } = req.body;

    if (typeof isEodChannel === 'boolean') channel.isEodChannel = isEodChannel;
    if (Array.isArray(summaryRecipientEmails))
      channel.eodConfig.summaryRecipientEmails = summaryRecipientEmails;
    if (cutoffTime !== undefined) channel.eodConfig.cutoffTime = cutoffTime;
    if (timezone !== undefined) channel.eodConfig.timezone = timezone;
    if (typeof autoSendOnComplete === 'boolean')
      channel.eodConfig.autoSendOnComplete = autoSendOnComplete;

    await channel.save();

    res.json({ isEodChannel: channel.isEodChannel, eodConfig: channel.eodConfig });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// GET /api/eod/:channelId/scheduled-today
// Preview who Trackio says is scheduled today (for the UI)
router.get('/:channelId/scheduled-today', protect, async (req, res) => {
  try {
    const channel = await Channel.findById(req.params.channelId);
    if (!channel) return res.status(404).json({ message: 'Channel not found' });

    const isMember = channel.members.some((m) => m.toString() === req.user._id.toString());
    if (!isMember) return res.status(403).json({ message: 'Not a member' });

    const scheduled = await getScheduledChannelMembers(channel, User, new Date());
    res.json({
      count: scheduled.length,
      members: scheduled.map((u) => ({
        _id: u._id,
        name: u.name,
        email: u.email,
        avatar: u.avatar,
      })),
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST /api/eod/:channelId/trigger - manual trigger
router.post('/:channelId/trigger', protect, async (req, res) => {
  try {
    const channel = await Channel.findById(req.params.channelId);
    if (!channel) return res.status(404).json({ message: 'Channel not found' });

    const isAdmin = await isWorkspaceAdmin(channel, req.user._id);
    if (!isAdmin) return res.status(403).json({ message: 'Only admins can trigger EOD' });

    const { date, force } = req.body;
    const targetDate = date ? new Date(date) : new Date();

    const result = await generateEodSummary({
      channelId: channel._id,
      date: targetDate,
      force: !!force,
    });

    res.json(result);
  } catch (err) {
    console.error('Manual trigger error:', err);
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;