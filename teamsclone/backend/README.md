# TeamsClone Backend

Real-time messaging backend powered by Node.js, Express, Socket.IO, and MongoDB.

## Setup

```bash
cd backend
npm install
cp .env.example .env
# Edit .env with your MongoDB, JWT, Cloudinary credentials
npm run dev
```

## Deploy to Render

1. Push to GitHub
2. New Web Service on Render → connect repo
3. Build Command: `npm install`
4. Start Command: `npm start`
5. Add env vars: `MONGO_URI`, `JWT_SECRET`, `CLOUDINARY_*`, `CLIENT_URL`

## API Endpoints

### Auth
- `POST /api/auth/register` — { name, email, password }
- `POST /api/auth/login` — { email, password }
- `GET /api/auth/me` — current user (auth)
- `GET /api/auth/users/search?q=name` — search users (auth)

### Workspaces
- `GET /api/workspaces` — user's workspaces
- `POST /api/workspaces` — { name, description }
- `POST /api/workspaces/join` — { inviteCode }
- `GET /api/workspaces/:id` — workspace details

### Channels
- `GET /api/channels/workspace/:workspaceId` — channels in workspace
- `GET /api/channels/dms` — user's DMs/groups
- `POST /api/channels` — create channel
- `POST /api/channels/dm` — { userId } → start DM
- `POST /api/channels/group` — { name, memberIds } → group chat

### Messages
- `GET /api/messages/:channelId?page=1&limit=50`
- `POST /api/messages` — { channel, content, attachments }
- `POST /api/messages/upload` — multipart file upload
- `PUT /api/messages/:id` — edit
- `DELETE /api/messages/:id` — delete
- `POST /api/messages/:id/react` — { emoji }

## Socket.IO Events

**Client → Server:**
- `channel:join`, `channel:leave`
- `typing:start`, `typing:stop`
- `message:read`

**Server → Client:**
- `message:new`, `message:updated`, `message:deleted`, `message:reaction`
- `user:status`
- `typing:start`, `typing:stop`
- `message:read`

**Auth:** Pass JWT in `socket.handshake.auth.token`
