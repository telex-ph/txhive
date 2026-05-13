const express = require('express');
const multer = require('multer');
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const cloudinary = require('cloudinary').v2;
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { protect } = require('../middleware/auth');

const router = express.Router();

const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });
};

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

const avatarStorage = new CloudinaryStorage({
  cloudinary,
  params: {
    folder: 'txhive/avatars',
    resource_type: 'image',
    allowed_formats: ['jpg', 'jpeg', 'png', 'webp'],
  },
});

const uploadAvatar = multer({
  storage: avatarStorage,
  limits: {
    fileSize: 3 * 1024 * 1024, // 3MB
  },
});

// POST /api/auth/register
router.post('/register', async (req, res) => {
  try {
    const { name, email, password } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ message: 'Please provide all fields' });
    }

    const exists = await User.findOne({ email });
    if (exists) return res.status(400).json({ message: 'User already exists' });

    const user = await User.create({ name, email, password });

    res.status(201).json({
      _id: user._id,
      name: user.name,
      email: user.email,
      avatar: user.avatar,
      token: generateToken(user._id),
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST /api/auth/login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email }).select('+password');

    if (!user || !(await user.matchPassword(password))) {
      return res.status(401).json({ message: 'Invalid email or password' });
    }

    user.status = 'online';
    user.lastSeen = new Date();
    await user.save();

    res.json({
      _id: user._id,
      name: user.name,
      email: user.email,
      avatar: user.avatar,
      token: generateToken(user._id),
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// GET /api/auth/me
router.get('/me', protect, async (req, res) => {
  res.json(req.user);
});

// PUT /api/auth/profile
router.put('/profile', protect, async (req, res) => {
  try {
    const { name, avatar, statusMessage } = req.body;
    const user = await User.findById(req.user._id);
    if (name) user.name = name;
    if (avatar !== undefined) user.avatar = avatar;
    if (statusMessage !== undefined) user.statusMessage = statusMessage;
    await user.save();
    res.json(user);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// GET /api/auth/users/search?q=name
router.get('/users/search', protect, async (req, res) => {
  try {
    const q = req.query.q || '';
    const users = await User.find({
      _id: { $ne: req.user._id },
      $or: [
        { name: { $regex: q, $options: 'i' } },
        { email: { $regex: q, $options: 'i' } },
      ],
    }).limit(20);
    res.json(users);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

const sanitizeProfileText = (value, maxLength = 120) => {
  return String(value || '').trim().slice(0, maxLength);
};

const publicUserFields =
  'name email avatar status statusMessage jobTitle department phone location lastSeen workspaces createdAt updatedAt';

// GET /api/auth/me
router.get('/me', protect, async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select(publicUserFields);

    if (!user) {
      return res.status(404).json({
        message: 'User not found',
      });
    }

    return res.json(user);
  } catch (err) {
    console.error('Get profile error:', err);
    return res.status(500).json({
      message: err.message || 'Failed to load profile',
    });
  }
});

// PUT /api/auth/me
router.put('/me', protect, async (req, res) => {
  try {
    const {
      name,
      status,
      statusMessage,
      jobTitle,
      department,
      phone,
      location,
    } = req.body;

    const updates = {};

    if (name !== undefined) {
      const cleanedName = sanitizeProfileText(name, 80);

      if (!cleanedName) {
        return res.status(400).json({
          message: 'Name is required',
        });
      }

      updates.name = cleanedName;
    }

    if (status !== undefined) {
      const allowedStatuses = ['online', 'offline', 'away', 'busy'];

      if (!allowedStatuses.includes(status)) {
        return res.status(400).json({
          message: 'Invalid status',
        });
      }

      updates.status = status;
    }

    if (statusMessage !== undefined) {
      updates.statusMessage = sanitizeProfileText(statusMessage, 160);
    }

    if (jobTitle !== undefined) {
      updates.jobTitle = sanitizeProfileText(jobTitle, 80);
    }

    if (department !== undefined) {
      updates.department = sanitizeProfileText(department, 80);
    }

    if (phone !== undefined) {
      updates.phone = sanitizeProfileText(phone, 40);
    }

    if (location !== undefined) {
      updates.location = sanitizeProfileText(location, 80);
    }

    const user = await User.findByIdAndUpdate(
      req.user._id,
      { $set: updates },
      { new: true }
    ).select(publicUserFields);

    if (!user) {
      return res.status(404).json({
        message: 'User not found',
      });
    }

    const io = req.app.get('io');
    if (io) {
      io.emit('user:updated', user);
    }

    return res.json(user);
  } catch (err) {
    console.error('Update profile error:', err);
    return res.status(500).json({
      message: err.message || 'Failed to update profile',
    });
  }
});

// POST /api/auth/me/avatar
router.post(
  '/me/avatar',
  protect,
  uploadAvatar.single('file'),
  async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({
          message: 'No avatar uploaded',
        });
      }

      const user = await User.findByIdAndUpdate(
        req.user._id,
        {
          $set: {
            avatar: req.file.path,
          },
        },
        { new: true }
      ).select(publicUserFields);

      if (!user) {
        return res.status(404).json({
          message: 'User not found',
        });
      }

      const io = req.app.get('io');
      if (io) {
        io.emit('user:updated', user);
      }

      return res.json(user);
    } catch (err) {
      console.error('Upload avatar error:', err);
      return res.status(500).json({
        message: err.message || 'Failed to upload avatar',
      });
    }
  }
);

// DELETE /api/auth/me/avatar
router.delete('/me/avatar', protect, async (req, res) => {
  try {
    const user = await User.findByIdAndUpdate(
      req.user._id,
      {
        $set: {
          avatar: '',
        },
      },
      { new: true }
    ).select(publicUserFields);

    if (!user) {
      return res.status(404).json({
        message: 'User not found',
      });
    }

    const io = req.app.get('io');
    if (io) {
      io.emit('user:updated', user);
    }

    return res.json(user);
  } catch (err) {
    console.error('Remove avatar error:', err);
    return res.status(500).json({
      message: err.message || 'Failed to remove avatar',
    });
  }
});

module.exports = router;
