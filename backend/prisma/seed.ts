// Seed database with demo users, posts and conversations.
// Run with: npm run db:seed
import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  const password = await bcrypt.hash('password123', 10);
  const usersData = [
    { email: 'mahdi@example.com', username: 'mahdi', name: 'Mahdi', bio: 'Building CHATE-MAHDI ✨', avatarUrl: '' },
    { email: 'sara@example.com', username: 'sara', name: 'Sara', bio: 'Photographer 📷', avatarUrl: '' },
    { email: 'omar@example.com', username: 'omar', name: 'Omar', bio: 'Traveler ✈️', avatarUrl: '' },
    { email: 'lina@example.com', username: 'lina', name: 'Lina', bio: 'Designer 🎨', avatarUrl: '' },
  ];

  const users: Record<string, string> = {};
  for (const u of usersData) {
    const user = await prisma.user.upsert({
      where: { email: u.email },
      update: {},
      create: { ...u, passwordHash: password },
    });
    users[u.username] = user.id;
  }

  // everyone follows everyone
  const ids = Object.values(users);
  for (const a of ids) {
    for (const b of ids) {
      if (a !== b) {
        await prisma.follow.upsert({
          where: { followerId_addresseeId: { followerId: a, addresseeId: b } },
          update: {},
          create: { followerId: a, addresseeId: b, status: 'ACCEPTED' },
        });
      }
    }
  }

  const sample = [
    { author: 'mahdi', caption: 'Golden hour 🌇 #sunset', mediaType: 'IMAGE', location: 'Baghdad' },
    { author: 'sara', caption: 'Morning light ☕ #coffee', mediaType: 'IMAGE', location: '' },
    { author: 'omar', caption: 'On the road ✈️ #travel', mediaType: 'IMAGE', location: 'Dubai' },
    { author: 'lina', caption: 'New design drops 🎨 #design', mediaType: 'IMAGE', location: '' },
  ];
  // Placeholder images are generated client-side; seed posts use picsum placeholders.
  for (let i = 0; i < sample.length; i++) {
    const s = sample[i];
    await prisma.post.create({
      data: {
        authorId: users[s.author],
        caption: s.caption,
        mediaType: s.mediaType,
        mediaUrl: `https://picsum.photos/seed/chatemahdi${i}/800/800`,
        location: s.location,
        hashtags: (s.caption.match(/#[\w\u0600-\u06FF]+/g) || []).map((h) => h.toLowerCase()),
      },
    });
  }

  // conversation between mahdi & sara
  const convo = await prisma.conversation.create({ data: { isGroup: false, title: '' } });
  const byU = (u: string) => ({ conversationId: convo.id, userId: users[u] });
  for (const u of ['mahdi', 'sara']) await prisma.participant.create({ data: byU(u) });
  await prisma.message.createMany({
    data: [
      { conversationId: convo.id, senderId: users.mahdi, content: 'مرحباً سارة 👋' },
      { conversationId: convo.id, senderId: users.sara, content: 'أهلاً مهدي، كيف تجرّب التطبيق؟' },
    ],
  });

  const story = await prisma.story.create({
    data: { authorId: users.mahdi, mediaUrl: 'https://picsum.photos/seed/cmstory/720/1280' },
  });
  await prisma.storyView.create({ data: { storyId: story.id, viewerId: users.sara } });

  console.log('Seeded: ' + Object.keys(users).join(', '));
  console.log('Demo password for all accounts: password123');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
