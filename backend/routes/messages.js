const express = require('express');
const multer = require('multer');
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const cloudinary = require('cloudinary').v2;
const Message = require('../models/Message');
const Channel = require('../models/Channel');
const Workspace = require('../models/Workspace');
const { protect } = require('../middleware/auth');
const { checkAndTriggerEod } = require('../services/eodSummarizer');

const router = express.Router();

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

const storage = new CloudinaryStorage({
  cloudinary,
  params: {
    folder: 'txhive',
    resource_type: 'auto',
  },
});

const upload = multer({ storage });

const toId = (value) => {
  if (!value) return '';

  if (value._id) {
    return value._id.toString();
  }

  return value.toString();
};

const isWorkspaceMember = async (workspaceId, userId) => {
  if (!workspaceId) return false;

  const workspace = await Workspace.findById(workspaceId);

  if (!workspace) return false;

  return workspace.members.some((member) => {
    const memberUser = member.user || member;
    return toId(memberUser) === toId(userId);
  });
};

const canAccessChannel = async (channel, userId) => {
  if (!channel) return false;

  const currentUserId = toId(userId);
  const memberIds = (channel.members || []).map((member) => toId(member));

  if (channel.type === 'dm' || channel.type === 'group') {
    return memberIds.includes(currentUserId);
  }

  if (channel.isPrivate) {
    return memberIds.includes(currentUserId);
  }

  if (memberIds.includes(currentUserId)) {
    return true;
  }

  return await isWorkspaceMember(channel.workspace, currentUserId);
};

// GET /api/messages/:channelId?page=1&limit=50
// GET /api/messages/:channelId?page=1&limit=50
router.get('/:channelId', protect, async (req, res) => {
  try {
    const channelId = req.params.channelId;

    const channel = await Channel.findById(channelId);

    if (!channel) {
      return res.status(404).json({
        message: 'Channel not found',
      });
    }

    const allowed = await canAccessChannel(channel, req.user._id);

    if (!allowed) {
      return res.status(403).json({
        message: 'You do not have access to this conversation',
      });
    }

    const page = parseInt(req.query.page, 10) || 1;
    const limit = parseInt(req.query.limit, 10) || 50;
    const skip = (page - 1) * limit;

    const messages = await Message.find({
      channel: channelId,
      deleted: false,
    })
      .populate('sender', 'name email avatar')
      .populate({
        path: 'replyTo',
        populate: {
          path: 'sender',
          select: 'name avatar',
        },
      })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    return res.json(messages.reverse());
  } catch (err) {
    console.error('❌ Load messages error:', err);

    return res.status(500).json({
      message: err.message || 'Failed to load messages',
    });
  }
});

// POST /api/messages - send message (also broadcast via socket + auto-trigger EOD)
// POST /api/messages - send message
router.post('/', protect, async (req, res) => {
  try {
    const { channel: channelId, content, attachments, replyTo } = req.body;

    if (!channelId) {
      return res.status(400).json({
        message: 'Channel is required',
      });
    }

    const channel = await Channel.findById(channelId);

    if (!channel) {
      return res.status(404).json({
        message: 'Channel not found',
      });
    }

    const allowed = await canAccessChannel(channel, req.user._id);

    if (!allowed) {
      return res.status(403).json({
        message: 'You cannot send messages to this conversation',
      });
    }

    if (!content && (!attachments || attachments.length === 0)) {
      return res.status(400).json({
        message: 'Content or attachment required',
      });
    }

    let message = await Message.create({
      channel: channelId,
      sender: req.user._id,
      content: content || '',
      attachments: attachments || [],
      replyTo: replyTo || null,
    });

    message = await message.populate('sender', 'name email avatar');

    if (replyTo) {
      message = await message.populate({
        path: 'replyTo',
        populate: {
          path: 'sender',
          select: 'name avatar',
        },
      });
    }

    await Channel.findByIdAndUpdate(channelId, {
      lastMessage: message._id,
      lastActivity: new Date(),
    });

    const payload = JSON.parse(JSON.stringify(message));

    const io = req.app.get('io');

    if (io) {
      const roomName = `channel:${channelId}`;
      const roomSize = io.sockets.adapter.rooms.get(roomName)?.size || 0;

      console.log(
        `📢 Broadcasting to ${roomName} | sockets in room: ${roomSize}`
      );

      io.to(roomName).emit('message:new', payload);
    }

    res.status(201).json(payload);

    if (channel.isEodChannel) {
      checkAndTriggerEod(channelId).catch((err) =>
        console.error('EOD auto-trigger error:', err.message)
      );
    }
  } catch (err) {
    console.error('❌ Send message error:', err);

    return res.status(500).json({
      message: err.message || 'Failed to send message',
    });
  }
});

// POST /api/messages/upload - upload file/image
router.post('/upload', protect, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ message: 'No file uploaded' });

    res.json({
      url: req.file.path,
      type: req.file.mimetype.startsWith('image/') ? 'image' : 'file',
      name: req.file.originalname,
      size: req.file.size,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// PUT /api/messages/:id - edit
router.put('/:id', protect, async (req, res) => {
  try {
    const message = await Message.findById(req.params.id);
    if (!message) return res.status(404).json({ message: 'Not found' });
    if (message.sender.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: 'Not allowed' });
    }
    message.content = req.body.content;
    message.edited = true;
    await message.save();

    const updatedMessage = await Message.findById(message._id)
      .populate('sender', 'name email avatar')
      .populate({
        path: 'replyTo',
        populate: {
          path: 'sender',
          select: 'name avatar',
        },
      });

    const io = req.app.get('io');

    if (io) {
      io.to(`channel:${message.channel}`).emit(
        'message:updated',
        updatedMessage,
      );
    }

    res.json(updatedMessage);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// DELETE /api/messages/:id - soft delete
router.delete('/:id', protect, async (req, res) => {
  try {
    const message = await Message.findById(req.params.id);
    if (!message) return res.status(404).json({ message: 'Not found' });
    if (message.sender.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: 'Not allowed' });
    }
    message.deleted = true;
    message.content = '';
    await message.save();

    const io = req.app.get('io');
    io.to(`channel:${message.channel}`).emit('message:deleted', { _id: message._id, channel: message.channel });

    res.json({ message: 'Deleted' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST /api/messages/:id/react - add/remove reaction
router.post('/:id/react', protect, async (req, res) => {
  try {
    const { emoji } = req.body;
    const message = await Message.findById(req.params.id);
    if (!message) return res.status(404).json({ message: 'Not found' });

    let reaction = message.reactions.find((r) => r.emoji === emoji);
    if (!reaction) {
      message.reactions.push({ emoji, users: [req.user._id] });
    } else {
      const idx = reaction.users.findIndex((u) => u.toString() === req.user._id.toString());
      if (idx >= 0) reaction.users.splice(idx, 1);
      else reaction.users.push(req.user._id);

      if (reaction.users.length === 0) {
        message.reactions = message.reactions.filter((r) => r.emoji !== emoji);
      }
    }
    await message.save();

    const io = req.app.get('io');
    io.to(`channel:${message.channel}`).emit('message:reaction', message);

    res.json(message);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;