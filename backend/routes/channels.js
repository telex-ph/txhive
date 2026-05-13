const express = require('express');
const Channel = require('../models/Channel');
const Workspace = require('../models/Workspace');
const Message = require('../models/Message');
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
// POST /api/channels/dm - start or get 1-on-1 DM
router.post('/dm', protect, async (req, res) => {
  try {
    const { userId, workspaceId } = req.body;

    if (!userId) {
      return res.status(400).json({ message: 'userId required' });
    }

    if (userId.toString() === req.user._id.toString()) {
      return res.status(400).json({
        message: 'You cannot send a private message to yourself',
      });
    }

    // Optional pero recommended:
    // Kapag may workspaceId, siguraduhin na parehong member ng workspace.
    if (workspaceId) {
      const ws = await Workspace.findById(workspaceId);

      if (!ws) {
        return res.status(404).json({ message: 'Workspace not found' });
      }

      const memberIds = ws.members.map((m) => m.user.toString());

      const currentUserIsMember = memberIds.includes(req.user._id.toString());
      const targetUserIsMember = memberIds.includes(userId.toString());

      if (!currentUserIsMember || !targetUserIsMember) {
        return res.status(403).json({
          message: 'Both users must be members of this workspace',
        });
      }
    }

    const query = {
      type: 'dm',
      members: {
        $all: [req.user._id, userId],
        $size: 2,
      },
    };

    // Para per-workspace ang DM kung may workspaceId kang sinend from Flutter.
    if (workspaceId) {
      query.workspace = workspaceId;
    }

    let dm = await Channel.findOne(query).populate(
      'members',
      'name email avatar status'
    );

    let created = false;

    if (!dm) {
      dm = await Channel.create({
        name: 'dm',
        type: 'dm',
        workspace: workspaceId || undefined,
        isPrivate: true,
        members: [req.user._id, userId],
        createdBy: req.user._id,
      });

      dm = await Channel.findById(dm._id).populate(
        'members',
        'name email avatar status'
      );

      created = true;
    }

    res.status(created ? 201 : 200).json(dm);
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

const normalizeChannelName = (value) => {
  return String(value || '')
    .trim()
    .replace(/^#+\s*/, '')
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9-_]/g, '');
};

const getMemberUserId = (member) => {
  const user = member.user || member;

  if (user && typeof user === 'object' && user._id) {
    return user._id.toString();
  }

  return user?.toString();
};

const canManageChannel = (workspace, channel, userId) => {
  const memberRecord = workspace.members.find(
    (member) => getMemberUserId(member) === userId.toString()
  );

  if (!memberRecord) return false;

  const role = String(memberRecord.role || '').toLowerCase();
  const isAdminOrOwner = role === 'admin' || role === 'owner';
  const isCreator = channel.createdBy?.toString() === userId.toString();

  return isAdminOrOwner || isCreator;
};

const updateChannel = async (req, res) => {
  try {
    const { name, description, isPrivate } = req.body;

    const channel = await Channel.findById(req.params.id);

    if (!channel) {
      return res.status(404).json({ message: 'Channel not found' });
    }

    if (channel.type !== 'channel') {
      return res.status(400).json({
        message: 'Only workspace channels can be updated',
      });
    }

    const workspace = await Workspace.findById(channel.workspace);

    if (!workspace) {
      return res.status(404).json({ message: 'Workspace not found' });
    }

    if (!canManageChannel(workspace, channel, req.user._id)) {
      return res.status(403).json({
        message: 'You do not have permission to update this channel',
      });
    }

    if (name !== undefined) {
      const cleanedName = normalizeChannelName(name);

      if (!cleanedName) {
        return res.status(400).json({
          message: 'Channel name is required',
        });
      }

      const duplicate = await Channel.findOne({
        _id: { $ne: channel._id },
        workspace: channel.workspace,
        type: 'channel',
        name: cleanedName,
      });

      if (duplicate) {
        return res.status(400).json({
          message: 'A channel with this name already exists',
        });
      }

      channel.name = cleanedName;
    }

    if (description !== undefined) {
      channel.description = String(description || '').trim();
    }

    if (isPrivate !== undefined) {
      const nextIsPrivate = Boolean(isPrivate);

      // Public -> Private:
      // Since wala ka pang invite/manage members UI, gawin muna private
      // sa current user + creator. Existing private members are preserved
      // kapag private na siya dati.
      if (nextIsPrivate && !channel.isPrivate) {
        const privateMembers = [
          req.user._id.toString(),
          channel.createdBy.toString(),
        ];

        channel.members = [...new Set(privateMembers)];
      }

      // Private/Public -> Public:
      // Lahat ng workspace members magiging members ng channel.
      if (!nextIsPrivate) {
        channel.members = workspace.members
          .map((member) => getMemberUserId(member))
          .filter(Boolean);
      }

      channel.isPrivate = nextIsPrivate;
    }

    await channel.save();

    const updatedChannel = await Channel.findById(channel._id).populate(
      'members',
      'name email avatar status'
    );

    const io = req.app.get('io');

    if (io && channel.workspace) {
      io.to(channel.workspace.toString()).emit(
        'channel:updated',
        updatedChannel
      );
    }

    return res.json(updatedChannel);
  } catch (err) {
    console.error('Update channel error:', err);
    return res.status(500).json({
      message: err.message || 'Failed to update channel',
    });
  }
};

router.put('/:id', protect, updateChannel);
router.patch('/:id', protect, updateChannel);

router.delete('/:id', protect, async (req, res) => {
  try {
    const channel = await Channel.findById(req.params.id);

    if (!channel) {
      return res.status(404).json({ message: 'Channel not found' });
    }

    if (channel.type !== 'channel') {
      return res.status(400).json({
        message: 'Only workspace channels can be deleted',
      });
    }

    const workspace = await Workspace.findById(channel.workspace);

    if (!workspace) {
      return res.status(404).json({ message: 'Workspace not found' });
    }

    if (!canManageChannel(workspace, channel, req.user._id)) {
      return res.status(403).json({
        message: 'You do not have permission to delete this channel',
      });
    }

    await Message.deleteMany({ channel: channel._id });
    await Channel.findByIdAndDelete(channel._id);

    const io = req.app.get('io');

    if (io && channel.workspace) {
      io.to(channel.workspace.toString()).emit('channel:deleted', {
        _id: channel._id.toString(),
        workspaceId: channel.workspace.toString(),
      });
    }

    return res.json({
      message: 'Channel deleted',
      _id: channel._id.toString(),
    });
  } catch (err) {
    console.error('Delete channel error:', err);
    return res.status(500).json({
      message: err.message || 'Failed to delete channel',
    });
  }
});

module.exports = router;
