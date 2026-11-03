{
  build_command: 'cmake --build build --clean-first --parallel 2',
  configure_command: 'cmake -B build -G Ninja -DCMAKE_TOOLCHAIN_FILE="${GITHUB_WORKSPACE}/.ios-cmake/ios.toolchain.cmake" -DDEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" -DENABLE_BITCODE=NO -DIOS_ARCHS="$IOS_ARCHS" -DPLATFORM=OS64 -DRHYDBG=ON -DENABLE_PATCHES=ON -DENABLE_OFFLINE_PATCHES=ON',
  documentation_steps: [
    {
      name: 'Install dependencies',
      run: 'sudo apt-get update\nsudo apt-get install -y doxygen graphviz\n',
    },
    {
      name: 'Configure',
      run: 'cmake -B "${GITHUB_WORKSPACE}/build" -DBUILD_DOCS_ONLY=ON',
    },
    {
      name: 'Build documentation',
      run: 'cmake --build "${GITHUB_WORKSPACE}/build" --target docs',
    },
    {
      name: 'Build API reference',
      run: "npm install --no-audit --no-fund --no-save \\\n  --prefix \"${RUNNER_TEMP}/scalar\" @scalar/api-reference@1.66.1\nmkdir -p \"${GITHUB_WORKSPACE}/build/html/api\"\ncp -R \"${RUNNER_TEMP}/scalar/node_modules/@scalar/api-reference/dist/browser\" \\\n  \"${GITHUB_WORKSPACE}/build/html/api/scalar\"\nfind \"${GITHUB_WORKSPACE}/build/html/api/scalar\" -name '*.map' -delete\n# The bundle queries api.scalar.com on load whatever it is configured with, and would\n# route a sent request through proxy.scalar.com. Point its service hosts at a name that\n# cannot resolve, so the page cannot reach them even where its policy is not enforced.\nfind \"${GITHUB_WORKSPACE}/build/html/api/scalar\" -name '*.js' -exec sed -i \\\n  -e 's#https://api\\.scalar\\.com#https://api.scalar.invalid#g' \\\n  -e 's#https://proxy\\.scalar\\.com#https://proxy.scalar.invalid#g' \\\n  -e 's#https://fonts\\.scalar\\.com#https://fonts.scalar.invalid#g' \\\n  -e 's#https://registry\\.scalar\\.com#https://registry.scalar.invalid#g' {} +\ncp openapi.yaml \"${GITHUB_WORKSPACE}/build/html/api/openapi.yaml\"\ncp docs/api/index.html \"${GITHUB_WORKSPACE}/build/html/api/index.html\"\n",
    },
  ],
  env: {
    BUILD_CONFIG: 'Release',
    DEPLOYMENT_TARGET: '12.0',
    IOS_ARCHS: 'arm64',
    IOS_CMAKE_REF: '21598aa550701d20654c032328f7e8710a14099b',
  },
  runs_on: 'macos-15',
  setup_steps: [
    {
      name: 'Install Ninja',
      run: 'brew install ninja',
    },
    {
      name: 'Fetch ios-cmake toolchain',
      run: 'git clone --revision="$IOS_CMAKE_REF" https://github.com/leetal/ios-cmake.git .ios-cmake\n',
    },
  ],
  workflow_file: 'pages.yml',
}
