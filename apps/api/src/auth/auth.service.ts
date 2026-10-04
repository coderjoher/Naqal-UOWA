import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../prisma/prisma.service';
import { runAsSystem } from '../tenancy/tenant-context';

/** Email + password login for office and super admin users (students/drivers come in P2). */
@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  async login(email: string, password: string) {
    const user = await runAsSystem(() => this.prisma.db.user.findUnique({ where: { email: email.toLowerCase() } }));
    // Compare against a dummy hash when the user is missing so timing does not reveal emails.
    const hash = user?.passwordHash ?? '$2b$10$CwTycUXWue0Thq9StjUM0uJ8.uYwTN.WoSh1gDj1q6E9V/OxSyZ4y';
    const ok = await bcrypt.compare(password, hash);
    if (!user || !ok || user.status !== 'active') throw new UnauthorizedException('Invalid email or password');

    const accessToken = await this.jwt.signAsync({ sub: user.id, role: user.role, uid: user.universityId });
    return {
      accessToken,
      user: { id: user.id, name: user.name, role: user.role, universityId: user.universityId },
    };
  }
}
