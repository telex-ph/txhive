const jwt = require('jsonwebtoken');
const User = require('../models/User');

const onlineUsers = new Map(); // userId -> Set of socketIds

const initSocket = (io) => {
  // Auth middleware for sockets
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth.token;
      if (!token) return next(new Error('No token'));
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const user = await User.findById(decoded.id);
      if (!user) return next(new Error('User not found'));
      socket.user = user;
      next();
    } catch (err) {
      next(new Error('Auth failed'));
    }
  });

  io.on('connection', async (socket) => {
    const userId = socket.user._id.toString();
    console.log(`🔌 User connected: ${socket.user.name} (${socket.id})`);

    // Track online
    if (!onlineUsers.has(userId)) onlineUsers.set(userId, new Set());
    onlineUsers.get(userId).add(socket.id);

    await User.findByIdAndUpdate(userId, { status: 'online', lastSeen: new Date() });
    io.emit('user:status', { userId, status: 'online' });

    socket.join(`user:${userId}`);

    // Join channel room
    socket.on('channel:join', (channelId) => {
      socket.join(`channel:${channelId}`);
    });

    // Leave channel room
    socket.on('channel:leave', (channelId) => {
      socket.leave(`channel:${channelId}`);
    });

    // Typing indicators
    socket.on('typing:start', ({ channelId }) => {
      socket.to(`channel:${channelId}`).emit('typing:start', {
        channelId,
        user: { _id: socket.user._id, name: socket.user.name },
      });
    });

    socket.on('typing:stop', ({ channelId }) => {
      socket.to(`channel:${channelId}`).emit('typing:stop', {
        channelId,
        userId: socket.user._id,
      });
    });

    // Read receipts
    socket.on('message:read', async ({ messageId, channelId }) => {
      socket.to(`channel:${channelId}`).emit('message:read', {
        messageId,
        userId,
        readAt: new Date(),
      });
    });

    // Disconnect
    socket.on('disconnect', async () => {
      console.log(`❌ User disconnected: ${socket.user.name}`);
      const userSockets = onlineUsers.get(userId);
      if (userSockets) {
        userSockets.delete(socket.id);
        if (userSockets.size === 0) {
          onlineUsers.delete(userId);
          await User.findByIdAndUpdate(userId, { status: 'offline', lastSeen: new Date() });
          io.emit('user:status', { userId, status: 'offline' });
        }
      }
    });
  });
};

module.exports = { initSocket, onlineUsers };
