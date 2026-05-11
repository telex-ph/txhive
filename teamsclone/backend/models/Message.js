const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema(
  {
    channel: { type: mongoose.Schema.Types.ObjectId, ref: 'Channel', required: true },
    sender: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    content: { type: String, default: '' },
    attachments: [
      {
        url: String,
        type: { type: String, enum: ['image', 'file', 'video', 'audio'] },
        name: String,
        size: Number,
      },
    ],
    replyTo: { type: mongoose.Schema.Types.ObjectId, ref: 'Message', default: null },
    reactions: [
      {
        emoji: String,
        users: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
      },
    ],
    readBy: [
      {
        user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
        readAt: { type: Date, default: Date.now },
      },
    ],
    edited: { type: Boolean, default: false },
    deleted: { type: Boolean, default: false },
  },
  { timestamps: true }
);

messageSchema.index({ channel: 1, createdAt: -1 });

module.exports = mongoose.model('Message', messageSchema);
