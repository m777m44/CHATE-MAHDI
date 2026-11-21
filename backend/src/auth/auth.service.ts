import { ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterDto, LoginDto } from './dto/auth.dto';
import { JwtPayload } from './jwt.strategy';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
  ) {}

  private signTokens(user: { id: string; username: string }) {
    const payload: Omit<JwtPayload, 'type'> = { sub: user.id, username: user.username };
    return {
      accessToken: this.jwt.sign({ ...payload, type: 'access' }, { secret: process.env.JWT_ACCESS_SECRET || 'dev-access-secret', expiresIn: process.env.JWT_ACCESS_TTL || '15m' }),
      refreshToken: this.jwt.sign({ ...payload, type: 'refresh' }, { secret: process.env.JWT_REFRESH_SECRET || 'dev-refresh-secret', expiresIn: process.env.JWT_REFRESH_TTL || '30d' }),
    };
  }

  async register(dto: RegisterDto) {
    if (!/^[a-zA-Z0-9._]+$/.test(dto.username)) {
      throw new ConflictException('Username may only contain letters, numbers, dots and underscores');
    }
    const exists = await this.prisma.user.findFirst({
      where: { OR: [{ email: dto.email.toLowerCase() }, { username: dto.username.toLowerCase() }] },
    });
    if (exists) throw new ConflictException('Email or username already in use');

    const user = await this.prisma.user.create({
      data: {
        email: dto.email.toLowerCase(),
        username: dto.username.toLowerCase(),
        name: dto.name || dto.username,
        passwordHash: await bcrypt.hash(dto.password, 10),
      },
    });
    return { user: this.sanitize(user), ...this.signTokens(user) };
  }

  async login(dto: LoginDto) {
    const identifier = dto.identifier.trim().toLowerCase();
    const user = await this.prisma.user.findFirst({
      where: { OR: [{ email: identifier }, { username: identifier }] },
    });
    if (!user || !(await bcrypt.compare(dto.password, user.passwordHash))) {
      throw new UnauthorizedException('Invalid credentials');
    }
    return { user: this.sanitize(user), ...this.signTokens(user) };
  }

  async refresh(refreshToken: string) {
    try {
      const payload: JwtPayload = this.jwt.verify(refreshToken, {
        secret: process.env.JWT_REFRESH_SECRET || 'dev-refresh-secret',
      });
      if (payload.type !== 'refresh') throw new UnauthorizedException();
      const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
      if (!user) throw new UnauthorizedException();
      return { user: this.sanitize(user), ...this.signTokens(user) };
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  private sanitize(user: {
    id: string; email: string; username: string; name: string; bio: string;
    avatarUrl: string; websiteUrl: string; isPrivate: boolean; createdAt: Date;
  }) {
    return {
      id: user.id, email: user.email, username: user.username, name: user.name,
      bio: user.bio, avatarUrl: user.avatarUrl, websiteUrl: user.websiteUrl,
      isPrivate: user.isPrivate, createdAt: user.createdAt,
    };
  }
}
