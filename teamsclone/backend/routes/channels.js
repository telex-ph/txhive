const express = require('express');
const Channel = require('../models/Channel');
const Workspace = require('../models/Workspace');
const { protect } = require('../middleware/auth');

const router = express.Router();

// GET /api/channels/workspace/:workspaceId - channels in workspace
router.get('/workspace/:workspaceId', protect, async (req, res) => {
  try {
    const channels = await Channel.find({
      workspace: req.params.workspaceId,
      type: 'channel',
      $or: [{ isPrivate: false }, { members: req.user._id }],
    }).sort({ name: 1 });

    res.json(channels);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// GET /api/channels/dms - all DMs ng user (1-on-1 + group)
router.get('/dms', protect, async (req, res) => {
  try {
    const dms = await Channel.find({
      type: { $in: ['dm', 'group'] },
      members: req.user._id,
    })
      .populate('members', 'name email avatar status')
      .populate('lastMessage')
      .sort({ lastActivity: -1 });

    res.json(dms);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST /api/channels - create channel
router.post('/', protect, async (req, res) => {
  try {
    const { name, description, workspace, isPrivate } = req.body;

    const ws = await Workspace.findById(workspace);
    if (!ws) return res.status(404).json({ message: 'Workspace not found' });

    const isMember = ws.members.some((m) => m.user.toString() === req.user._id.toString());
    if (!isMember) return res.status(403).json({ message: 'Not a member of workspace' });

    const channel = await Channel.create({
      name: name.toLowerCase().replace(/\s+/g, '-'),
      description,
      type: 'channel',
      workspace,
      isPrivate: !!isPrivate,
      members: isPrivate ? [req.user._id] : ws.members.map((m) => m.user),
      createdBy: req.user._id,
    });

    res.status(201).json(channel);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST /api/channels/dm - start or get 1-on-1 DM
router.post('/dm', protect, async (req, res) => {
  try {
    const { userId } = req.body;
    if (!userId) return res.status(400).json({ message: 'userId required' });

    let dm = await Channel.findOne({
      type: 'dm',
      members: { $all: [req.user._id, userId], $size: 2 },
    }).populate('members', 'name email avatar status');

    if (!dm) {
      dm = await Channel.create({
        name: 'dm',
        type: 'dm',
        members: [req.user._id, userId],
        createdBy: req.user._id,
      });
      dm = await dm.populate('members', 'name email avatar status');
    }

    res.json(dm);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST /api/channels/group - create group DM
router.post('/group', protect, async (req, res) => {
  try {
    const { name, memberIds } = req.body;
    if (!memberIds || memberIds.length < 2) {
      return res.status(400).json({ message: 'At least 2 members required' });
    }

    const members = [...new Set([req.user._id.toString(), ...memberIds])];

    const group = await Channel.create({
      name: name || 'Group Chat',
      type: 'group',
      members,
      createdBy: req.user._id,
    });

    const populated = await Channel.findById(group._id).populate('members', 'name email avatar status');
    res.status(201).json(populated);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
