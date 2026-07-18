{
  uses_user_defaults: true,
  project_name: 'expert-rotary-phone',
  version: '2.0.3',
  security_policy_supported_versions: { '2.0.x': ':white_check_mark:' },
  description: 'Expert Rotary Phone.',
  keywords: ['decompilation', 'game', 'ios', 'reverse engineering', 'rhythmin'],
  want_codeql: false,
  want_tests: false,
  project_type: 'other',
  shared_ignore+: [
    '*.ipa',
    '*.ips',
    '.arm64-dbg/',
    '.decompile/',
    '.venv/',
    '/.audit/',
    '/.ios-cmake/',
    '/.theos-install/',
    '/.to-format.txt',
    '/Project/.audit/',
    '/build/',
    '/logs/',
    '/screenshots/',
    '/theos/.theos/',
    '/theos/obj/',
    '/theos/packages/',
    'CMakeCache.txt',
    '__pycache__/',
    'sugoroku_chara_msg.bin',
    'sugoroku_chara_msg.generated.inc',
  ],
  prettierignore+: [
    '*.c',
    '*.cmake',
    '*.cpp',
    '*.h',
    '*.m',
    '*.mm',
    '*.strings',
    '/3rdparty/ziparchive/minizip/ChangeLogUnzip',
    'Makefile',
    'control',
  ],
  package_json+: {
    cspell+: {
      ignorePaths+: [
        '*.pbxproj',
        '*.xc*',
        '3rdparty/',
      ],
    },
    prettier+: {
      overrides+: [
        {
          files: ['*.plist', '*.plist.in'],
          options: {
            parser: 'xml',
          },
        },
      ],
    },
    local cmake_defines = [
      'CMAKE_TOOLCHAIN_FILE="./.ios-cmake/ios.toolchain.cmake"',
      'DEPLOYMENT_TARGET=12.0',
      'ENABLE_BITCODE=NO',
      'IOS_ARCHS=arm64',
      'PLATFORM=OS64',
    ],
    local cmake_build_args = [
      '--build',
      'build',
      '--config',
      'Release',
      '--',
      'CODE_SIGN_IDENTITY=-',
      'CODE_SIGNING_ALLOWED=YES',
      'CODE_SIGNING_REQUIRED=NO',
      'AD_HOC_CODE_SIGNING_ALLOWED=YES',
      'DEVELOPMENT_TEAM=""',
      'PROVISIONING_PROFILE_SPECIFIER=""',
    ],
    local cmake_package_ipa_commands = [
      'app=$(find build -type d -name PopnRhythmin.app -print -quit)',
      'test -n "${app}"',
      'codesign --force --sign - --timestamp=none "${app}"',
      'codesign --verify --verbose=2 "${app}"',
      'mkdir -p build/ipa/Payload',
      'cp -R "${app}" build/ipa/Payload/',
      '/usr/bin/zip -qry build/PopnRhythmin-latest.ipa build/ipa/Payload',
    ],
    local cmake_build_commands = [
      'if ! [ -d .ios-cmake ]; then git clone --depth 1 --branch "$IOS_CMAKE_REF" https://github.com/leetal/ios-cmake.git .ios-cmake; fi',
      'cmake -B build -G Xcode %s' % std.join(' ', ['-D%s' % d for d in cmake_defines]),
      'cmake %s' % std.join(' ', cmake_build_args),
    ] + cmake_package_ipa_commands,
    local check_formatting_commands = [
      "find -iname '*.m' -o -iname '*.mm' -o -iname '*.h' -o -iname '*.c' -o -iname '*.cpp' > .to-format.txt",
      'clang-format --dry-run --Werror --files=.to-format.txt',
      'rm -f .to-format.txt',
      'prettier --check .',
      'markdownlint-cli2 --config package.json --configPointer /markdownlint-cli2',
    ],
    local format_commands = [
      "find -iname '*.m' -o -iname '*.mm' -o -iname '*.h' -o -iname '*.c' -o -iname '*.cpp' > .to-format.txt",
      'clang-format -i --files=.to-format.txt',
      'rm -f .to-format.txt',
      'prettier -w .',
      'markdownlint-cli2 --config package.json --configPointer /markdownlint-cli2 --fix',
    ],
    scripts+: {
      build: std.join(' && ', cmake_build_commands),
      'check-formatting': std.join(' && ', check_formatting_commands),
      format: std.join(' && ', format_commands),
      qa: 'yarn check-spelling && yarn check-formatting',
    },
  },
  vscode+: {
    extensions+: {
      recommendations+: [
      ],
    },
    settings+: {
      '[c]': {
        'editor.indentSize': 'tabSize',
        'editor.tabSize': 4,
      },
      '[cpp]': {
        'editor.indentSize': 'tabSize',
        'editor.tabSize': 4,
      },
      '[objective-c]': {
        'editor.indentSize': 'tabSize',
        'editor.tabSize': 4,
      },
      '[objective-cpp]': {
        'editor.indentSize': 'tabSize',
        'editor.tabSize': 4,
      },
    },
  },
  cz+: {
    commitizen+: {
      version_files+: [
        'CMakeLists.txt',
        'theos/Resources/Info.plist',
        'theos/control',
      ],
    },
  },
  pre_commit_config+: {
    repos+: [
      {
        hooks: [
          {
            id: 'clang-format',
            types_or: [
              'c',
              'c++',
            ],
          },
        ],
        repo: 'https://github.com/pre-commit/mirrors-clang-format',
        rev: 'v22.1.5',
      },
    ],
  },
}
