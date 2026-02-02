# Upstream Fixes TODO for True Environment-Only Configuration

This document tracks issues that need to be fixed in Antragsgruen upstream to enable **true** environment-variable-only deployment without requiring any `config.json` file.

## Current Status (v4.17-volt)

The v4.17-volt tag adds environment variable support, but `config.json` is still required to exist (even if minimal). This defeats the purpose of 12-factor app deployment.

**Workaround**: The docker-entrypoint.sh automatically creates a minimal config.json with just `siteSubdomain` setting.

---

## Issues to Fix Upstream

### 1. **CRITICAL: index.php requires config.json to exist**

**File**: `web/index.php`
**Line**: ~20-30 (config.json existence check)

**Problem**:
```php
if (!file_exists($configFile) && !file_exists($installFile)) {
    die('Antragsgrün is not configured yet. Please create the config/INSTALLING file...');
}
```

This check happens BEFORE the web.php code that handles environment variables. Even though `config/web.php` can gracefully handle missing config.json (by using `$config = '{}'`), the application never reaches that code.

**Solution Needed**:
Remove or update this check to allow missing config.json when environment variables are set. Suggested approach:
```php
// Allow missing config.json if environment variables are configured
$hasEnvConfig = !empty($_SERVER['RANDOM_SEED']) && !empty($_SERVER['DB_HOST']);
if (!file_exists($configFile) && !file_exists($installFile) && !$hasEnvConfig) {
    die('Antragsgrün is not configured yet...');
}
```

**Impact**: HIGH - This is the main blocker for true env-only deployment

---

### 2. **CRITICAL: No SITE_SUBDOMAIN environment variable for single-site mode**

**File**: `models/settings/AntragsgruenApp.php` (EnvironmentConfigLoader)
**Documentation**: `docs/environment-variables.md`

**Problem**:
In single-site mode, the application needs to know which site subdomain to use. Currently, this MUST be in config.json:
```json
{
  "multisiteMode": false,
  "siteSubdomain": "std"
}
```

There's no environment variable equivalent for `siteSubdomain`.

**Solution Needed**:
Add a `SITE_SUBDOMAIN` environment variable that works when `MULTISITE_MODE=false`:

```php
// In EnvironmentConfigLoader::parseConfig()
if (isset($_SERVER['SITE_SUBDOMAIN'])) {
    $config['siteSubdomain'] = $_SERVER['SITE_SUBDOMAIN'];
}
```

**Default behavior**: If not set in single-site mode, default to "std" or the first site in the database.

**Impact**: HIGH - Required for single-site deployments without config.json

---

### 3. **MEDIUM: Root URL fails in single-site mode with env-only config**

**File**: `controllers/Base.php`
**Line**: 603

**Problem**:
Accessing the root URL (/) in single-site mode throws an error:
```
Error: Attempt to read property "urlPath" on null in /var/www/html/controllers/Base.php:603
```

The consultation object is null when accessing root. Accessing the consultation directly (e.g., `/main`) works fine.

**Solution Needed**:
When in single-site mode and consultation is null at root URL, either:
1. Automatically redirect to the first/default consultation
2. Show a better landing page
3. Load the default consultation automatically

**Impact**: MEDIUM - Root URL should work, but users can access via consultation path

---

### 4. **LOW: Documentation unclear about config.json requirement**

**File**: `docs/environment-variables.md`

**Problem**:
The documentation states:
> "Environment variables are used as fallback only. Config.json values take precedence when present."

This doesn't clearly explain:
- Whether config.json is optional or required
- What minimal config.json is needed if any
- How to do a pure environment-variable deployment

**Solution Needed**:
Add a section like:
```markdown
## Pure Environment Variable Deployment

To deploy using only environment variables without config.json:
1. Set RANDOM_SEED, DB_HOST, DB_NAME, DB_USER, DB_PASSWORD (required)
2. Set SITE_SUBDOMAIN for single-site mode
3. Set other optional variables as needed
4. No config.json file is needed - the application will create one automatically or load from environment

Note: In v4.17-volt, a minimal config.json is still required due to legacy checks. This will be removed in a future version.
```

**Impact**: LOW - Documentation clarity, not a functional issue

---

### 5. **LOW: Inconsistent environment variable naming**

**File**: `models/settings/EnvironmentConfigLoader.php`

**Problem**:
Some settings have multiple env var names for the same purpose:
- `TABLE_PREFIX` and `DB_TABLE_PREFIX` both work
- This could cause confusion

**Solution Needed**:
Document which is the canonical name and deprecate aliases, or clearly document all aliases in the environment variables documentation.

**Impact**: LOW - Works but could be cleaner

---

## Priority Order for Fixes

1. **Fix #1** (index.php check) - Without this, config.json must exist
2. **Fix #2** (SITE_SUBDOMAIN env var) - Required for single-site env-only deployment
3. **Fix #3** (Root URL handling) - Better UX but workaround exists
4. **Fix #4** (Documentation) - Helps users understand capabilities
5. **Fix #5** (Naming consistency) - Nice to have

---

## Testing Checklist

After upstream fixes, verify:

- [ ] Application starts with NO config.json file present
- [ ] Single-site mode works with SITE_SUBDOMAIN environment variable
- [ ] Multi-site mode works with MULTISITE_MODE=true
- [ ] Root URL (/) works correctly in both modes
- [ ] All database operations work with DB_* environment variables
- [ ] Redis integration works with REDIS_* environment variables
- [ ] Mail sending works with MAILER_DSN environment variable
- [ ] Application domain and protocol work with APP_DOMAIN and APP_PROTOCOL

---

## How to Use This Document

When ready to fix upstream:

1. Share this document with the Antragsgruen maintainers or create GitHub issues
2. Reference specific issue numbers in pull requests
3. For LLM-assisted fixes:
   - Provide this document as context
   - Point to specific file/line numbers mentioned above
   - Request fixes in priority order
   - Test each fix independently before combining

---

## Related Resources

- **Original MR**: https://github.com/CatoTH/antragsgruen/pull/1108
- **Environment Variables Docs**: https://github.com/CatoTH/antragsgruen/blob/v4.17-volt/docs/environment-variables.md
- **Tag**: v4.17-volt
- **Current workaround**: See `php-fpm/docker-entrypoint.sh` in this repository

---

**Last Updated**: 2026-02-02
**Status**: Workaround implemented in motion-tools-container, upstream fixes pending
