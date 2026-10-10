Unlike ConfigCache, the guard does not catch Redis errors: if Redis is down, rate-limited endpoints (sign-in, OTP) fail instead of degrading open.
