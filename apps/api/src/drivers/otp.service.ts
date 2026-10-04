import { HttpException, HttpStatus, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import { randomInt } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service';

/** Sends SMS. The console sender logs codes; a real gateway (e.g. an Iraqi SMS provider) plugs in here. */
export interface SmsSender {
  send(phone: string, text: string): Promise<void>;
}

export const SMS_SENDER = Symbol('SMS_SENDER');

export class ConsoleSmsSender implements SmsSender {
  private readonly log = new Logger('SMS');
  async send(phone: string, text: string) {
    this.log.log(`to ${phone}: ${text}`);
  }
}

const TTL_MS = 5 * 60_000;
const RESEND_MS = 60_000;
const MAX_ATTEMPTS = 5;

@Injectable()
export class OtpService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  /** Creates a code. Returns it only when OTP_DEV_ECHO=true (local/testing without an SMS gateway). */
  async issue(phone: string, sms: SmsSender): Promise<{ devCode?: string }> {
    const db = this.prisma.db;
    const existing = await db.otpCode.findUnique({ where: { phone } });
    if (existing && Date.now() - existing.createdAt.getTime() < RESEND_MS) {
      throw new HttpException('Wait a minute before requesting another code', HttpStatus.TOO_MANY_REQUESTS);
    }
    const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
    const data = { codeHash: await bcrypt.hash(code, 8), expiresAt: new Date(Date.now() + TTL_MS), attempts: 0, createdAt: new Date() };
    await db.otpCode.upsert({ where: { phone }, create: { phone, ...data }, update: data });
    await sms.send(phone, `رمز الدخول إلى نقل وارث: ${code}`);
    return this.config.get('OTP_DEV_ECHO') === 'true' ? { devCode: code } : {};
  }

  /** True once per issued code; wrong guesses are counted and the code dies after 5. */
  async consume(phone: string, code: string): Promise<boolean> {
    const db = this.prisma.db;
    const row = await db.otpCode.findUnique({ where: { phone } });
    if (!row || row.expiresAt < new Date() || row.attempts >= MAX_ATTEMPTS) return false;
    if (!(await bcrypt.compare(code, row.codeHash))) {
      await db.otpCode.update({ where: { phone }, data: { attempts: { increment: 1 } } });
      return false;
    }
    await db.otpCode.delete({ where: { phone } });
    return true;
  }
}
