import path from "node:path";
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Pin the workspace root: without it Next walks up past the repo and warns
  // about stray lockfiles in the home directory.
  turbopack: { root: path.resolve(__dirname) },
};

export default nextConfig;
