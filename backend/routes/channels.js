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

const uniqueIds = (items) => {
  return [...new Set((items || []).map((item) => item.toString()))];
};

router.post('/', protect, async (req, res) => {
  try {
    const { name, description, workspace, isPrivate, memberIds } = req.body;

    const ws = await Workspace.findById(workspace);
    if (!ws) return res.status(404).json({ message: 'Workspace not found' });

    const workspaceMemberIds = ws.members.map((m) => m.user.toString());

    const isMember = workspaceMemberIds.includes(req.user._id.toString());
    if (!isMember) {
      return res.status(403).json({ message: 'Not a member of workspace' });
    }

    const cleanedName = String(name || '')
      .trim()
      .replace(/^#+\s*/, '')
      .toLowerCase()
      .replace(/\s+/g, '-');

    if (!cleanedName) {
      return res.status(400).json({ message: 'Channel name is required' });
    }

    let channelMembers;

    if (isPrivate) {
      const requestedMembers = uniqueIds(memberIds);
      const allowedRequestedMembers = requestedMembers.filter((id) =>
        workspaceMemberIds.includes(id)
      );

      channelMembers = uniqueIds([
        req.user._id.toString(),
        ...allowedRequestedMembers,
      ]);
    } else {
      channelMembers = workspaceMemberIds;
    }

    const channel = await Channel.create({
      name: cleanedName,
      description,
      type: 'channel',
      workspace,
      isPrivate: !!isPrivate,
      members: channelMembers,
      admins: [req.user._id],
      createdBy: req.user._id,
    });

    const populated = await Channel.findById(channel._id)
      .populate('members', 'name email avatar status')
      .populate('admins', 'name email avatar status')
      .populate('createdBy', 'name email avatar status');

    res.status(201).json(populated);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

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

      if (nextIsPrivate && !channel.isPrivate) {
        channel.members = normalizeIdList([
          channel.createdBy,
          req.user._id,
          ...(channel.admins || []),
        ]);
      }

      if (!nextIsPrivate) {
        const workspace = await Workspace.findById(channel.workspace);
        channel.members = getWorkspaceMemberIds(workspace);
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

    if (!isChannelOwnerOrAdmin(channel, req.user._id)) {
      return res.status(403).json({
        message: 'Only the channel owner or channel admin can delete this channel',
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

const toId = (value) => {
  if (!value) return '';

  if (value._id) {
    return value._id.toString();
  }

  return value.toString();
};

const normalizeIdList = (items) => {
  return [...new Set(((items || []).map((item) => toId(item))).filter(Boolean))];
};

const isChannelOwnerOrAdmin = (channel, userId) => {
  const currentUserId = toId(userId);
  const ownerId = toId(channel.createdBy);
  const adminIds = normalizeIdList(channel.admins);

  return ownerId === currentUserId || adminIds.includes(currentUserId);
};

const isChannelMember = (channel, userId) => {
  const currentUserId = toId(userId);
  const memberIds = normalizeIdList(channel.members);

  return memberIds.includes(currentUserId);
};

const getWorkspaceMemberIds = (workspace) => {
  return workspace.members
    .map((member) => toId(member.user || member))
    .filter(Boolean);
};

// GET /api/channels/:id/members
// Returns current channel members + workspace members para sa checkbox UI.
router.get('/:id/members', protect, async (req, res) => {
  try {
    const channel = await Channel.findById(req.params.id)
      .populate('members', 'name email avatar status')
      .populate('admins', 'name email avatar status')
      .populate('createdBy', 'name email avatar status');

    if (!channel) {
      return res.status(404).json({ message: 'Channel not found' });
    }

    if (channel.type !== 'channel') {
      return res.status(400).json({
        message: 'Only workspace channels have member settings',
      });
    }

    const canView =
      !channel.isPrivate ||
      isChannelMember(channel, req.user._id) ||
      isChannelOwnerOrAdmin(channel, req.user._id);

    if (!canView) {
      return res.status(403).json({
        message: 'You do not have access to this private channel',
      });
    }

    const workspace = await Workspace.findById(channel.workspace).populate(
      'members.user',
      'name email avatar status'
    );

    if (!workspace) {
      return res.status(404).json({ message: 'Workspace not found' });
    }

    const workspaceMembers = workspace.members
      .map((member) => member.user)
      .filter(Boolean);

    return res.json({
      channel,
      members: channel.members,
      admins: channel.admins,
      createdBy: channel.createdBy,
      workspaceMembers,
      canManage: isChannelOwnerOrAdmin(channel, req.user._id),
    });
  } catch (err) {
    console.error('Get channel members error:', err);
    return res.status(500).json({
      message: err.message || 'Failed to load channel members',
    });
  }
});

// PUT /api/channels/:id/members
// Bulk update ng private channel members.
router.put('/:id/members', protect, async (req, res) => {
  try {
    const { memberIds } = req.body;

    const channel = await Channel.findById(req.params.id);

    if (!channel) {
      return res.status(404).json({ message: 'Channel not found' });
    }

    if (channel.type !== 'channel') {
      return res.status(400).json({
        message: 'Only workspace channels can be updated',
      });
    }

    if (!isChannelOwnerOrAdmin(channel, req.user._id)) {
      return res.status(403).json({
        message: 'Only channel owner or channel admin can manage members',
      });
    }

    if (!channel.isPrivate) {
      return res.status(400).json({
        message: 'Specific member control is only available for private channels',
      });
    }

    const workspace = await Workspace.findById(channel.workspace);

    if (!workspace) {
      return res.status(404).json({ message: 'Workspace not found' });
    }

    const workspaceMemberIds = getWorkspaceMemberIds(workspace);
    const requestedMemberIds = normalizeIdList(memberIds);

    const allowedMemberIds = requestedMemberIds.filter((id) =>
      workspaceMemberIds.includes(id)
    );

    // Owner/admin/current user should not accidentally lose access.
    const requiredMemberIds = normalizeIdList([
      channel.createdBy,
      req.user._id,
      ...(channel.admins || []),
    ]);

    channel.members = normalizeIdList([
      ...allowedMemberIds,
      ...requiredMemberIds,
    ]);

    await channel.save();

    const updatedChannel = await Channel.findById(channel._id)
      .populate('members', 'name email avatar status')
      .populate('admins', 'name email avatar status')
      .populate('createdBy', 'name email avatar status');

    const io = req.app.get('io');

    if (io && channel.workspace) {
      io.to(channel.workspace.toString()).emit('channel:updated', updatedChannel);
    }

    return res.json(updatedChannel);
  } catch (err) {
    console.error('Update channel members error:', err);
    return res.status(500).json({
      message: err.message || 'Failed to update channel members',
    });
  }
});

// POST /api/channels/:id/members
// Add one member.
router.post('/:id/members', protect, async (req, res) => {
  try {
    const { userId } = req.body;

    const channel = await Channel.findById(req.params.id);

    if (!channel) {
      return res.status(404).json({ message: 'Channel not found' });
    }

    if (!isChannelOwnerOrAdmin(channel, req.user._id)) {
      return res.status(403).json({
        message: 'Only channel owner or channel admin can add members',
      });
    }

    if (!channel.isPrivate) {
      return res.status(400).json({
        message: 'Specific member control is only available for private channels',
      });
    }

    const workspace = await Workspace.findById(channel.workspace);

    if (!workspace) {
      return res.status(404).json({ message: 'Workspace not found' });
    }

    const workspaceMemberIds = getWorkspaceMemberIds(workspace);

    if (!workspaceMemberIds.includes(userId.toString())) {
      return res.status(400).json({
        message: 'User must be a member of the workspace first',
      });
    }

    const currentMembers = normalizeIdList(channel.members);
    channel.members = normalizeIdList([...currentMembers, userId]);

    await channel.save();

    const updatedChannel = await Channel.findById(channel._id)
      .populate('members', 'name email avatar status')
      .populate('admins', 'name email avatar status')
      .populate('createdBy', 'name email avatar status');

    const io = req.app.get('io');

    if (io && channel.workspace) {
      io.to(channel.workspace.toString()).emit('channel:updated', updatedChannel);
    }

    return res.json(updatedChannel);
  } catch (err) {
    console.error('Add channel member error:', err);
    return res.status(500).json({
      message: err.message || 'Failed to add channel member',
    });
  }
});

// DELETE /api/channels/:id/members/:userId
// Remove one member.
router.delete('/:id/members/:userId', protect, async (req, res) => {
  try {
    const channel = await Channel.findById(req.params.id);

    if (!channel) {
      return res.status(404).json({ message: 'Channel not found' });
    }

    if (!isChannelOwnerOrAdmin(channel, req.user._id)) {
      return res.status(403).json({
        message: 'Only channel owner or channel admin can remove members',
      });
    }

    if (!channel.isPrivate) {
      return res.status(400).json({
        message: 'Specific member control is only available for private channels',
      });
    }

    const removeUserId = req.params.userId.toString();

    if (toId(channel.createdBy) === removeUserId) {
      return res.status(400).json({
        message: 'Channel owner cannot be removed',
      });
    }

    const adminIds = normalizeIdList(channel.admins);

    if (adminIds.includes(removeUserId)) {
      return res.status(400).json({
        message: 'Channel admin cannot be removed. Remove admin role first.',
      });
    }

    channel.members = normalizeIdList(channel.members).filter(
      (memberId) => memberId !== removeUserId
    );

    await channel.save();

    const updatedChannel = await Channel.findById(channel._id)
      .populate('members', 'name email avatar status')
      .populate('admins', 'name email avatar status')
      .populate('createdBy', 'name email avatar status');

    const io = req.app.get('io');

    if (io && channel.workspace) {
      io.to(channel.workspace.toString()).emit('channel:updated', updatedChannel);
    }

    return res.json(updatedChannel);
  } catch (err) {
    console.error('Remove channel member error:', err);
    return res.status(500).json({
      message: err.message || 'Failed to remove channel member',
    });
  }
});

module.exports = router;
