`<Route path="*" element={<RedirectOnce to="/" />}>` in App.tsx: any unknown URL is replaced (history replace) with the Overview index, which in turn bounces to /login when unauthenticated.
