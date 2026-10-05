import { Body, Controller, Get, HttpCode, Post } from '@nestjs/common';
import { ApiProperty, ApiTags } from '@nestjs/swagger';
import { IsString, Length, Matches, MaxLength, MinLength } from 'class-validator';
import { Public } from '../auth/decorators';
import { PrismaService } from '../prisma/prisma.service';
import { runAsSystem } from '../tenancy/tenant-context';
import { identityConfig } from './identity.factory';
import { StudentAuthService } from './student-auth.service';
import { LOGIN_LIMITS, RateLimit } from '../security/rate-limit';

class StudentLoginDto {
  @ApiProperty() @Matches(/^[a-z0-9-]{2,40}$/) university: string;
  @ApiProperty() @IsString() @MaxLength(40) studentId: string;
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(200) password: string;
}

class ActivateDto {
  @ApiProperty() @Matches(/^[a-z0-9-]{2,40}$/) university: string;
  @ApiProperty() @IsString() @MaxLength(40) studentId: string;
  @ApiProperty() @Length(6, 6) @Matches(/^\d{6}$/) code: string;
  @ApiProperty() @IsString() @MinLength(8) @MaxLength(200) password: string;
}

class SsoDto {
  @ApiProperty() @Matches(/^[a-z0-9-]{2,40}$/) university: string;
  @ApiProperty() @IsString() @MaxLength(8000) idToken: string;
}

@ApiTags('auth')
@Controller()
export class StudentAuthController {
  constructor(
    private readonly auth: StudentAuthService,
    private readonly prisma: PrismaService,
  ) {}

  @Public()
  @Post('auth/student/login')
  @RateLimit(...LOGIN_LIMITS)
  @HttpCode(200)
  login(@Body() dto: StudentLoginDto) {
    return this.auth.login(dto.university, dto.studentId, dto.password);
  }

  @Public()
  @Post('auth/student/activate')
  @RateLimit(...LOGIN_LIMITS)
  @HttpCode(200)
  activate(@Body() dto: ActivateDto) {
    return this.auth.activate(dto.university, dto.studentId, dto.code, dto.password);
  }

  @Public()
  @Post('auth/student/sso')
  @RateLimit(...LOGIN_LIMITS)
  @HttpCode(200)
  sso(@Body() dto: SsoDto) {
    return this.auth.sso(dto.university, dto.idToken);
  }

  /** Universities the apps can sign in to, with the sign-in method each one uses. */
  @Public()
  @Get('public/universities')
  async universities() {
    const list = await runAsSystem(() => this.prisma.db.university.findMany({ orderBy: { name: 'asc' } }));
    return list.map((u) => {
      const cfg = identityConfig(u.integrationConfig);
      return {
        slug: u.slug,
        name: u.name,
        nameAr: u.nameAr,
        studentSignIn: cfg.type,
        // OIDC apps need where to send the student; never expose secrets.
        sso: cfg.type === 'oidc' ? { issuer: cfg.issuer, audience: cfg.audience } : undefined,
      };
    });
  }
}
