import { BadRequestException, Injectable, NotFoundException, ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../prisma/prisma.service';
import { runAsTenant } from '../tenancy/tenant-context';
import { createIdentityProvider, identityConfig } from './identity.factory';
import { ProviderUnavailableError, StudentRecord } from './identity-provider';
import { RosterStore } from './roster.provider';

const DUMMY_HASH = '$2b$10$CwTycUXWue0Thq9StjUM0uJ8.uYwTN.WoSh1gDj1q6E9V/OxSyZ4y';

@Injectable()
export class StudentAuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  private async university(slug: string) {
    const uni = await this.prisma.db.university.findUnique({ where: { slug } });
    if (!uni) throw new NotFoundException('Unknown university');
    return uni;
  }

  private rosterStore(): RosterStore {
    const db = this.prisma.db;
    return {
      find: async (studentId) => db.rosterEntry.findFirst({ where: { studentId } }),
      recordFailedAttempt: async (id) => void (await db.rosterEntry.update({ where: { id }, data: { activationAttempts: { increment: 1 } } })),
    };
  }

  private async verify(uniConfig: unknown, input: { studentId?: string; secret: string }) {
    const provider = createIdentityProvider(identityConfig(uniConfig), this.rosterStore());
    try {
      return { provider, record: await provider.verify(input) };
    } catch (e) {
      if (e instanceof ProviderUnavailableError) throw new ServiceUnavailableException('The university system is not reachable. Try again in a few minutes.');
      throw e;
    }
  }

  /** Create or refresh the local student from the university record. Gender always comes from the record (ST-02). */
  private async upsertStudent(universityId: string, r: StudentRecord, passwordHash?: string) {
    const data = { name: r.name, nameAr: r.nameAr ?? null, gender: r.gender, ...(passwordHash ? { passwordHash } : {}) };
    return this.prisma.db.user.upsert({
      where: { universityId_studentId: { universityId, studentId: r.studentId } },
      create: { universityId, role: 'student', studentId: r.studentId, ...data },
      update: data,
    });
  }

  private async session(user: { id: string; name: string; role: 'student'; universityId: string | null; status: string }) {
    if (user.status !== 'active') throw new UnauthorizedException('Account suspended');
    const accessToken = await this.jwt.signAsync({ sub: user.id, role: user.role, uid: user.universityId });
    return { accessToken, user: { id: user.id, name: user.name, role: user.role, universityId: user.universityId } };
  }

  /** ST-01. Manual universities: local password set at activation. HTTP universities: verified live. */
  async login(slug: string, studentId: string, password: string) {
    const uni = await this.university(slug);
    return runAsTenant(uni.id, async () => {
      const cfg = identityConfig(uni.integrationConfig);
      if (cfg.type === 'oidc') throw new BadRequestException('This university signs in with its SSO page');
      if (cfg.type === 'manual') {
        const user = await this.prisma.db.user.findFirst({ where: { studentId: studentId.trim(), role: 'student' } });
        const ok = await bcrypt.compare(password, user?.passwordHash ?? DUMMY_HASH);
        if (!user || !ok) throw new UnauthorizedException('Student number or password is incorrect');
        return this.session({ ...user, role: 'student' });
      }
      const { record } = await this.verify(uni.integrationConfig, { studentId: studentId.trim(), secret: password });
      if (!record) throw new UnauthorizedException('Student number or password is incorrect');
      return this.session({ ...(await this.upsertStudent(uni.id, record)), role: 'student' });
    });
  }

  /** Manual universities: first sign-in with the code from the office; the student chooses a password. */
  async activate(slug: string, studentId: string, code: string, password: string) {
    const uni = await this.university(slug);
    if (identityConfig(uni.integrationConfig).type !== 'manual') throw new BadRequestException('Activation codes are not used at this university');
    return runAsTenant(uni.id, async () => {
      const { record } = await this.verify(uni.integrationConfig, { studentId, secret: code });
      if (!record) throw new UnauthorizedException('The activation code is wrong or has expired. Ask the transport office for a new one.');
      const user = await this.upsertStudent(uni.id, record, await bcrypt.hash(password, 10));
      await this.prisma.db.rosterEntry.update({
        where: { universityId_studentId: { universityId: uni.id, studentId: record.studentId } },
        data: { activationCodeHash: null, activationExpiresAt: null, activatedAt: new Date(), activationAttempts: 0 },
      });
      return this.session({ ...user, role: 'student' });
    });
  }

  /** OIDC universities: the app sends the ID token obtained from the university SSO. */
  async sso(slug: string, idToken: string) {
    const uni = await this.university(slug);
    if (identityConfig(uni.integrationConfig).type !== 'oidc') throw new BadRequestException('This university does not use SSO');
    return runAsTenant(uni.id, async () => {
      const { record } = await this.verify(uni.integrationConfig, { secret: idToken });
      if (!record) throw new UnauthorizedException('Sign-in was not accepted by the university');
      return this.session({ ...(await this.upsertStudent(uni.id, record)), role: 'student' });
    });
  }
}
