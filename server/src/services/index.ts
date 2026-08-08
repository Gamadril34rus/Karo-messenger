// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export class AuthService {
  async register(phone: string, email?: string, password: string = '', username?: string) {
    const existingUser = await prisma.user.findFirst({
      where: { phone },
    });
    if (existingUser) {
      throw new Error('User already exists');
    }
    const hashedPassword = await this.hashPassword(password);
    const user = await prisma.user.create({
      data: { phone, email, username: username ?? phone, passwordHash: hashedPassword, status: 'ACTIVE' },
    });
    return user;
  }

  async login(phone: string, password: string) {
    const user = await prisma.user.findFirst({ where: { phone, status: 'ACTIVE' } });
    if (!user || !user.passwordHash || !password) {
      throw new Error('Invalid credentials');
    }
    const valid = await this.verifyPassword(password, user.passwordHash);
    if (!valid) {
      throw new Error('Invalid credentials');
    }
    return user;
  }

  async deleteAccount(userId: string) {
    await prisma.user.update({
      where: { id: userId },
      data: { status: 'DELETED' as any, deletedAt: new Date() },
    });
  }

  async hashPassword(password: string): Promise<string> {
    const bcrypt = await import('bcryptjs');
    return bcrypt.hash(password, 12);
  }

  async verifyPassword(password: string, hash: string): Promise<boolean> {
    const bcrypt = await import('bcryptjs');
    return bcrypt.compare(password, hash!);
  }
}

export class ChatService {
  async createChat(type: string, title?: string, createdBy?: string) {
    return prisma.chat.create({
      data: { type: type as any, title, createdBy },
    });
  }

  async getChats(userId: string, page = 1, limit = 20) {
    const skip = (page - 1) * limit;
    return prisma.chatMember.findMany({
      where: { userId },
      include: { chat: { include: { messages: { take: 1, orderBy: { createdAt: 'desc' } } } } },
      skip,
      take: limit,
    });
  }

  async getChat(chatId: string) {
    return prisma.chat.findUnique({
      where: { id: chatId },
      include: { members: true },
    });
  }

  async addMember(chatId: string, userId: string, role = 'MEMBER') {
    return prisma.chatMember.create({
      data: { chatId, userId, role: role as any },
    });
  }

  async deleteChat(chatId: string) {
    return prisma.chat.delete({ where: { id: chatId } });
  }
}

export class MessageService {
  async sendMessage(chatId: string, senderId: string, type: string, content?: any) {
    return prisma.message.create({
      data: { chatId, senderId, type: type as any, content },
    });
  }

  async getMessages(chatId: string, page = 1, limit = 50) {
    const skip = (page - 1) * limit;
    return prisma.message.findMany({
      where: { chatId, isDeleted: false },
      orderBy: { createdAt: 'asc' },
      skip,
      take: limit,
    });
  }

  async editMessage(messageId: string, content: any) {
    return prisma.message.update({
      where: { id: messageId },
      data: { content, isEdited: true },
    });
  }

  async deleteMessage(messageId: string) {
    return prisma.message.update({
      where: { id: messageId },
      data: { isDeleted: true },
    });
  }

  async markRead(messageId: string, userId: string) {
    return prisma.messageStatus.upsert({
      where: { messageId_userId: { messageId, userId } },
      create: { messageId, userId, status: 'READ' },
      update: { status: 'READ' },
    });
  }
}

export class UserService {
  async getUser(userId: string) {
    return prisma.user.findUnique({ where: { id: userId } });
  }

  async updateUser(userId: string, data: { username?: string; displayName?: string; bio?: string; avatarUrl?: string }) {
    return prisma.user.update({ where: { id: userId }, data });
  }

  async searchUsers(query: string) {
    return prisma.user.findMany({
      where: {
        OR: [
          { username: { contains: query, mode: 'insensitive' } },
          { displayName: { contains: query, mode: 'insensitive' } },
        ],
        status: 'ACTIVE',
      },
      take: 20,
    });
  }
}

export class StickerService {
  async getStickerPacks(page = 1, limit = 20) {
    const skip = (page - 1) * limit;
    return prisma.stickerPack.findMany({ skip, take: limit });
  }

  async importStickerPack(data: { name: string; source: string; sourceId?: string; stickers: any[] }) {
    return prisma.stickerPack.create({
      data: {
        name: data.name,
        source: data.source as any,
        sourceId: data.sourceId,
        stickers: { create: data.stickers },
      },
      include: { stickers: true },
    });
  }
}
