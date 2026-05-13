const mongoose = require('mongoose');

const channelSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    description: { type: String, default: '' },
    type: { type: String, enum: ['channel', 'dm', 'group'], default: 'channel' },
    isPrivate: { type: Boolean, default: false },
    workspace: { type: mongoose.Schema.Types.ObjectId, ref: 'Workspace' },
    members: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    admins: {
      type: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
      default: [],
    },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    lastMessage: { type: mongoose.Schema.Types.ObjectId, ref: 'Message' },
    lastActivity: { type: Date, default: Date.now },

    // EOD Channel configuration (Trackio-integrated)
    // Expected submitters are auto-fetched from Trackio daily — no manual list
    isEodChannel: { type: Boolean, default: false },
    eodConfig: {
      summaryRecipientEmails: [{ type: String }],
      cutoffTime: { type: String, default: '19:00' },
      timezone: { type: String, default: 'Asia/Manila' },
      autoSendOnComplete: { type: Boolean, default: true },
      lastSummaryDate: { type: String, default: '' },
    },
  },
  { timestamps: true }
);

channelSchema.index({ workspace: 1, name: 1 });

module.exports = mongoose.model('Channel', channelSchema);