/**
 * Commitlint configuration for helm-charts repository
 *
 * Enforces conventional commits specification with chart-specific scopes.
 * Reference: https://www.conventionalcommits.org/
 *
 * Commit format: <type>(<scope>): <subject>
 *
 * Types:
 *   feat     - A new feature
 *   fix      - A bug fix
 *   docs     - Documentation only changes
 *   style    - Changes that do not affect the meaning of the code
 *   refactor - A code change that neither fixes a bug nor adds a feature
 *   perf     - A code change that improves performance
 *   test     - Adding missing tests or correcting existing tests
 *   build    - Changes that affect the build system or external dependencies
 *   ci       - Changes to CI configuration files and scripts
 *   chore    - Other changes that don't modify src or test files
 *   revert   - Reverts a previous commit
 *
 * Scopes (optional):
 *   - Chart names: cloudflared, olm, mdbook-htmx, etc.
 *   - General: deps, ci, docs, release, main
 */

export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // Type must be one of the allowed values
    'type-enum': [
      2,
      'always',
      [
        'feat',
        'fix',
        'docs',
        'style',
        'refactor',
        'perf',
        'test',
        'build',
        'ci',
        'chore',
        'revert',
      ],
    ],

    // Type is required and must be lowercase
    'type-case': [2, 'always', 'lower-case'],
    'type-empty': [2, 'never'],

    // Scope is optional but if present must be lowercase
    // Allow chart names and general scopes
    'scope-case': [2, 'always', 'lower-case'],
    'scope-enum': [
      1, // Warning only - allow new charts without config update
      'always',
      [
        // Chart names (update when adding new charts)
        'cloudflared',
        'olm',
        'mdbook-htmx',
        // General scopes
        'deps',
        'ci',
        'docs',
        'release',
        'main',
        'integration',
        // Allow empty scope
        '',
      ],
    ],

    // Subject (description) rules
    'subject-case': [
      2,
      'never',
      ['sentence-case', 'start-case', 'pascal-case', 'upper-case'],
    ],
    'subject-empty': [2, 'never'],
    'subject-full-stop': [2, 'never', '.'],
    'subject-max-length': [2, 'always', 72],

    // Header (full first line) rules
    'header-max-length': [2, 'always', 100],

    // Body rules
    'body-leading-blank': [2, 'always'],
    'body-max-line-length': [1, 'always', 100], // Warning only for body

    // Footer rules (warning only - GitHub squash commits often lack blank line before footer)
    'footer-leading-blank': [1, 'always'],
    'footer-max-line-length': [1, 'always', 100], // Warning only for footer

    // Signed commits (optional - warning only)
    'signed-off-by': [0, 'always', 'Signed-off-by:'],
  },

  // Custom parser options for release-please commits
  parserPreset: {
    parserOpts: {
      headerPattern: /^(\w*)(?:\(([^)]*)\))?!?: (.*)$/,
      headerCorrespondence: ['type', 'scope', 'subject'],
      noteKeywords: ['BREAKING CHANGE', 'BREAKING-CHANGE'],
      revertPattern:
        /^(?:Revert|revert:)\s"?([\s\S]+?)"?\s*This reverts commit (\w*)\./i,
      revertCorrespondence: ['header', 'hash'],
    },
  },

  // Ignore auto-generated commits
  ignores: [
    (commit) => commit.startsWith('chore(main): release'),
    (commit) => commit.startsWith('chore(release):'),
    // Ignore merge commits
    (commit) => commit.startsWith('Merge '),
    (commit) => commit.startsWith('Merge pull request'),
  ],
};
