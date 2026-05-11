const mongoose = require('mongoose');

const workspaceSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    description: { type: String, default: '' },
    icon: { type: String, default: '' },
    owner: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    members: [
      {
        user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
        role: { type: String, enum: ['admin', 'member'], default: 'member' },
        joinedAt: { type: Date, default: Date.now },
      },
    ],
    inviteCode: { type: String, unique: true },
  },
  { timestamps: true }
);

workspaceSchema.pre('save', function (next) {
  if (!this.inviteCode) {
    this.inviteCode = Math.random().toString(36).substring(2, 10).toUpperCase();
  }
  next();
});

module.exports = mongoose.model('Workspace', workspaceSchema);
