/** @type {import('next').NextConfig} */
const nextConfig = {
    output: 'export',
    // compiler: {
    //     removeConsole: {
    //         exclude: ['error'],
    //     },
    // },
    basePath: process.env.UI_BASE_PATH || '/ui',
    env: {
        NEXT_PUBLIC_PROXY_BASE_URL: process.env.PROXY_BASE_URL || 
            (process.env.NODE_ENV === 'development' ? 'http://localhost:4000' : ''),
    },
};

nextConfig.experimental = {
    missingSuspenseWithCSRBailout: false
}

export default nextConfig;
