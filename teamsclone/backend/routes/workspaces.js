const express = require('express');
const Workspace = require('../models/Workspace');
const Channel = require('../models/Channel');
const User = require('../models/User');
const { protect } = require('../middleware/auth');

const router = express.Router();

// GET /api/workspaces - all workspaces ng user
router.get('/', protect, async (req, res) => {
  try {
    const workspaces = await Workspace.find({ 'members.user': req.user._id })
      .populate('owner', 'name email avatar')
      .sort({ updatedAt: -1 });
    res.json(workspaces);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST /api/workspaces - create workspace
router.post('/', protect, async (req, res) => {
  try {
    const { name, description } = req.body;
    if (!name) return res.status(400).json({ message: 'Name required' });

    const workspace = await Workspace.create({
      name,
      description,
      owner: req.user._id,
      members: [{ user: req.user._id, role: 'admin' }],
    });

    // Auto-create General channel
    await Channel.create({
      name: 'general',
      description: 'Main channel for the workspace',
      type: 'channel',
      workspace: workspace._id,
      members: [req.user._id],
      createdBy: req.user._id,
    });

    await User.findByIdAndUpdate(req.user._id, {
      $addToSet: { workspaces: workspace._id },
    });

    res.status(201).json(workspace);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST /api/workspaces/join - join via invite code
router.post('/join', protect, async (req, res) => {
  try {
    const { inviteCode } = req.body;
    const workspace = await Workspace.findOne({ inviteCode: inviteCode?.toUpperCase() });
    if (!workspace) return res.status(404).json({ message: 'Invalid invite code' });

    const already = workspace.members.find((m) => m.user.toString() === req.user._id.toString());
    if (already) return res.status(400).json({ message: 'Already a member' });

    workspace.members.push({ user: req.user._id, role: 'member' });
    await workspace.save();

    // Add user to general channel
    await Channel.updateMany(
      { workspace: workspace._id, type: 'channel', isPrivate: false },
      { $addToSet: { members: req.user._id } }
    );

    await User.findByIdAndUpdate(req.user._id, { $addToSet: { workspaces: workspace._id } });

    res.json(workspace);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// GET /api/workspaces/:id - workspace details + members
router.get('/:id', protect, async (req, res) => {
  try {
    const workspace = await Workspace.findById(req.params.id)
      .populate('owner', 'name email avatar')
      .populate('members.user', 'name email avatar status');

    if (!workspace) return res.status(404).json({ message: 'Workspace not found' });

    const isMember = workspace.members.some((m) => m.user._id.toString() === req.user._id.toString());
    if (!isMember) return res.status(403).json({ message: 'Not a member' });

    res.json(workspace);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
