import { Transform } from 'class-transformer';
import { stripPhone } from './phone';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsOptional, IsString, Matches, Max, MaxLength, Min } from 'class-validator';

export class RequestOtpDto {
  @ApiProperty({ example: '07701234567' }) @Transform(stripPhone) @Matches(/^(\+?964|0)?7\d{9}$/, { message: 'Enter an Iraqi mobile number' }) phone: string;
}

export class VerifyOtpDto {
  @ApiProperty() @Transform(stripPhone) @Matches(/^(\+?964|0)?7\d{9}$/) phone: string;
  @ApiProperty() @Matches(/^\d{6}$/) code: string;
  /** Needed only the first time (new driver chooses the university). */
  @ApiPropertyOptional() @IsOptional() @Matches(/^[a-z0-9-]{2,40}$/) university?: string;
}

export class UpdateApplicationDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(120) name?: string;
  @ApiPropertyOptional() @IsOptional() @Matches(/^[a-z][a-z0-9_]{1,30}$/) vehicleType?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(30) plate?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) @Max(80) seats?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1980) @Max(2100) modelYear?: number;
}

export class ReviewDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(500) note?: string;
}
