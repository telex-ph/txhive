const mongoose = require('mongoose');

const channelSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    description: { type: String, default: '' },
    type: { type: String, enum: ['channel', 'dm', 'group'], default: 'channel' },
    isPrivate: { type: Boolean, default: false },
    workspace: { type: mongoose.Schema.Types.ObjectId, ref: 'Workspace' },
    members: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    lastMessage: { type: mongoose.Schema.Types.ObjectId, ref: 'Message' },
    lastActivity: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

channelSchema.index({ workspace: 1, name: 1 });

module.exports = mongoose.model('Channel', channelSchema);
