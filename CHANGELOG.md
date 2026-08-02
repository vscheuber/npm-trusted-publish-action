# Changelog

## Unreleased

## [v1.1.0] - 2026-08-02

### Added
- Introduced dual release support, enabling stable versions to be released alongside companion pre-releases. This feature allows for more flexible release management and testing workflows. (39580b9)

## [v1.0.9] - 2026-08-02

### Changed
- Updated input descriptions in `action.yml` to clarify usage and remove unused parameters, streamlining the configuration process for users. (commit 8026157)

### Removed
- Eliminated redundant code from `publish.sh`, reducing complexity and potential maintenance overhead. (commit 8026157)

## [v1.0.8] - 2026-08-02

### Added
- Implemented `fetch_dist_tags` and `put_dist_tag` functions to enhance npm dist-tag management. These functions allow for more efficient handling of dist-tags during the publishing process, improving overall control and automation. (commit 65d8940)

## [v1.0.7] - 2026-08-02

### Added
- Introduced `dist-tag-token` input to support npm granular write token usage, allowing for more precise control over npm dist-tag mutations. This enhancement is reflected in `action.yml` and `publish.sh` and documented in the README. (6f03461, 03a0099)

### Fixed
- Enabled `fetch-tags` in the checkout step to ensure accurate versioning during the publishing process. This fix addresses potential issues with version retrieval and ensures consistency. (cbfca41)

## [v1.0.6] - 2026-08-02

### Added
- Introduced a recovery mode for already published packages, enhancing the robustness of the publishing process. This feature helps manage scenarios where a package has been previously published, reducing potential disruptions. Updates have been made to `action.yml` and `publish.sh` to support this functionality. (commit eda5349)

### Changed
- Updated outputs in `action.yml` and `publish.sh` to reflect the new recovery mode capabilities, ensuring users receive accurate feedback during the publishing process. (commit eda5349)

## [v1.0.5] - 2026-08-02

### Added
- Enhanced descriptions in `README.md` and `action.yml` to provide clearer guidance on handling stable releases and managing `next` dist-tags. This aims to improve user understanding and ease of use for stable release processes. (commit e74289a)

### Changed
- Updated `publish.sh` script to better handle `next` dist-tag management, ensuring smoother transitions and more reliable publishing workflows for users. (commit e74289a)

## [v1.0.4] - 2026-08-02

### Changed
- Internal pipeline update release. This release updates CI/CD or release automation under `.github/` without changing functional behavior.

## [v1.0.3] - 2026-08-01

### Added
- Integration of AI action for release notes, streamlining changelog updates and improving release documentation efficiency (commit 5fa6631).
- Promotion of release notes to versioned changelog section in the release workflow, ensuring accurate historical documentation (commit a302bad).

## [v1.0.3-1] - 2026-08-01

### Added
- Initial implementation of npm trusted publish action with CI and release workflows.
- Feature to add tagging for major and minor versions during release (#4013701).
- Promotion of release notes to versioned changelog section in the release workflow.

### Documentation
- Updated README with improved clarity in the prerequisites section and detailed permissions requirements.
- Added example workflow for npm trusted publishing in the README.

## [v1.0.1-1] - 2026-08-01

### Added
- Initial implementation of npm trusted publish action with CI and release workflows.
- Feature to add tagging for major and minor versions during release (#4013701).

### Documentation
- Updated README with improved clarity in the prerequisites section and detailed permissions requirements.
- Added example workflow for npm trusted publishing in the README.

