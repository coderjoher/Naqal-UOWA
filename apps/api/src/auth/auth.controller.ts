import { Body, Controller, Get, HttpCode, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { PrismaService } from '../prisma/prisma.service';
import { AuthService } from './auth.service';
import { LoginDto } from './auth.dto';
import { AuthUser, CurrentUser, Public } from './decorators';
import { LOGIN_LIMITS, RateLimit } from '../security/rate-limit';

@ApiTags('auth')
@Controller()
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly prisma: PrismaService,
  ) {}

  @Public()
  @Post('auth/login')
  @RateLimit(...LOGIN_LIMITS)
  @HttpCode(200)
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto.email, dto.password);
  }

  @ApiBearerAuth()
  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    return this.prisma.db.user.findUniqueOrThrow({
      where: { id: user.id },
      select: { id: true, name: true, email: true, phone: true, role: true, gender: true, universityId: true },
    });
  }
}
