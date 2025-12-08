#!/bin/sh
# Database initialization script for Antragsgruen
# This script initializes the database on first run if AUTO_INIT_DB is enabled

set -e

echo "[init-db] Starting database initialization check"

# Configuration with defaults
AUTO_INIT_DB="${AUTO_INIT_DB:-true}"
ANTRAGSGRUEN_MODE="${ANTRAGSGRUEN_MODE:-single-site}"
DEFAULT_SITE_SUBDOMAIN="${DEFAULT_SITE_SUBDOMAIN:-demo}"
DEFAULT_SITE_TITLE="${DEFAULT_SITE_TITLE:-Demo Site}"
DEFAULT_SITE_ORG="${DEFAULT_SITE_ORG:-Demo Organization}"
DEFAULT_CONSULTATION_TITLE="${DEFAULT_CONSULTATION_TITLE:-Main Consultation}"
DEFAULT_CONSULTATION_PATH="${DEFAULT_CONSULTATION_PATH:-main}"

# Check if auto-init is disabled
if [ "$AUTO_INIT_DB" != "true" ]; then
    echo "[init-db] AUTO_INIT_DB is disabled, skipping database initialization"
    return 0 2>/dev/null || exit 0
fi

# Wait for database to be ready
echo "[init-db] Waiting for database connection..."
max_attempts=30
attempt=0
until mysql -h "$DB_HOST" -P "${DB_PORT:-3306}" -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1" "$DB_NAME" >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ $attempt -ge $max_attempts ]; then
        echo "[init-db] ERROR: Could not connect to database after $max_attempts attempts"
        return 1 2>/dev/null || exit 1
    fi
    echo "[init-db] Database not ready, waiting... (attempt $attempt/$max_attempts)"
    sleep 2
done

echo "[init-db] Database connection successful"

# Check if database is already initialized
table_count=$(mysql -h "$DB_HOST" -P "${DB_PORT:-3306}" -u "$DB_USER" -p"$DB_PASSWORD" -N -s -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME' AND table_name='site'" "$DB_NAME" 2>/dev/null || echo "0")

if [ "$table_count" -gt 0 ]; then
    echo "[init-db] Database already initialized (site table exists), skipping"
    return 0 2>/dev/null || exit 0
fi

echo "[init-db] Database is empty, initializing..."

# Import base schema with TABLE_PREFIX replaced
echo "[init-db] Importing database schema..."
if [ -f /var/www/html/assets/db/create.sql ]; then
    sed 's/###TABLE_PREFIX###//g' /var/www/html/assets/db/create.sql | \
        mysql -h "$DB_HOST" -P "${DB_PORT:-3306}" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME"
    echo "[init-db] Schema imported successfully"
else
    echo "[init-db] ERROR: Schema file not found at /var/www/html/assets/db/create.sql"
    return 1 2>/dev/null || exit 1
fi

# Mark all migrations as applied
echo "[init-db] Marking migrations as applied..."
migration_sql="/tmp/mark_migrations.sql"
cat > "$migration_sql" << 'EOF'
INSERT INTO migration (version, apply_time) VALUES
  ('m000000_000000_base', UNIX_TIMESTAMP()),
  ('m150930_094343_amendment_multiple_paragraphs', UNIX_TIMESTAMP()),
  ('m151021_084634_supporter_organization_contact_person', UNIX_TIMESTAMP()),
  ('m151025_123256_user_email_change', UNIX_TIMESTAMP()),
  ('m151104_092212_motion_type_deletable', UNIX_TIMESTAMP()),
  ('m151104_132242_site_consultation_date_creation', UNIX_TIMESTAMP()),
  ('m151106_083636_site_properties', UNIX_TIMESTAMP()),
  ('m151106_183055_motion_type_two_cols', UNIX_TIMESTAMP()),
  ('m160114_200337_motion_section_is_right', UNIX_TIMESTAMP()),
  ('m160228_152511_motion_type_rename_initiator_form', UNIX_TIMESTAMP()),
  ('m160304_095858_motion_slug', UNIX_TIMESTAMP()),
  ('m160305_201135_support_separate_to_motions_and_amendments', UNIX_TIMESTAMP()),
  ('m160305_214526_support_likes_dislikes', UNIX_TIMESTAMP()),
  ('m160605_104819_remove_consultation_type', UNIX_TIMESTAMP()),
  ('m161112_161536_add_date_delete', UNIX_TIMESTAMP()),
  ('m170111_182139_motions_non_amendable', UNIX_TIMESTAMP()),
  ('m170129_173812_typo_maintenance', UNIX_TIMESTAMP()),
  ('m170204_191243_additional_user_fields', UNIX_TIMESTAMP()),
  ('m170206_185458_supporter_contact_name', UNIX_TIMESTAMP()),
  ('m170226_134156_motionInitiatorsAmendmentMerging', UNIX_TIMESTAMP()),
  ('m170419_182728_delete_consultation_admin', UNIX_TIMESTAMP()),
  ('m170611_195343_global_alternatives', UNIX_TIMESTAMP()),
  ('m170730_094020_amendment_proposed_changes', UNIX_TIMESTAMP()),
  ('m170807_193931_voting_status', UNIX_TIMESTAMP()),
  ('m170826_180536_proposal_notifications', UNIX_TIMESTAMP()),
  ('m170923_151852_proposal_explanation', UNIX_TIMESTAMP()),
  ('m171219_173517_motion_proposed_changes', UNIX_TIMESTAMP()),
  ('m171231_093702_user_organization_ids', UNIX_TIMESTAMP()),
  ('m180519_180908_siteTexts', UNIX_TIMESTAMP()),
  ('m180524_153540_motionTypeDeadlines', UNIX_TIMESTAMP()),
  ('m180531_062049_parent_motion_ids', UNIX_TIMESTAMP()),
  ('m180602_121824_motion_create_buttons', UNIX_TIMESTAMP()),
  ('m180604_080335_notification_settings', UNIX_TIMESTAMP()),
  ('m180605_125835_consultation_files', UNIX_TIMESTAMP()),
  ('m180609_095225_consultation_text_in_menu', UNIX_TIMESTAMP()),
  ('m180619_080947_email_settings_to_consultations', UNIX_TIMESTAMP()),
  ('m180621_113721_login_settings_to_consultation', UNIX_TIMESTAMP()),
  ('m180623_113955_motionTypeSettings', UNIX_TIMESTAMP()),
  ('m180901_131243_sectionPrintTitle', UNIX_TIMESTAMP()),
  ('m180902_182805_initiatorSettings', UNIX_TIMESTAMP()),
  ('m180906_171118_supporterExtraData', UNIX_TIMESTAMP()),
  ('m181027_094836_fix_amendment_comment_relation', UNIX_TIMESTAMP()),
  ('m181027_174827_consultationFilesSite', UNIX_TIMESTAMP()),
  ('m181101_161124_proposed_procedure_active', UNIX_TIMESTAMP()),
  ('m190816_074556_votingData', UNIX_TIMESTAMP()),
  ('m190901_065243_deleteOldMergingDrafts', UNIX_TIMESTAMP()),
  ('m191101_162351_motion_responsibility', UNIX_TIMESTAMP()),
  ('m191201_080255_motion_support_types', UNIX_TIMESTAMP()),
  ('m191208_065712_file_downloads', UNIX_TIMESTAMP()),
  ('m191222_135810_lualatex', UNIX_TIMESTAMP()),
  ('m200107_113326_motionSectionSettings', UNIX_TIMESTAMP()),
  ('m200125_124424_minimalistic_ui', UNIX_TIMESTAMP()),
  ('m200130_100306_agenda_extension', UNIX_TIMESTAMP()),
  ('m200223_161553_agenda_obsoletion', UNIX_TIMESTAMP()),
  ('m200301_110040_user_settings', UNIX_TIMESTAMP()),
  ('m200329_135701_speech_list', UNIX_TIMESTAMP()),
  ('m200621_063838_amendmentMotionExtraData', UNIX_TIMESTAMP()),
  ('m201111_193448_consultation_text_per_motion_type', UNIX_TIMESTAMP()),
  ('m210116_080438_rename_email_blocklist', UNIX_TIMESTAMP()),
  ('m210207_145533_remove_obsolete_fields', UNIX_TIMESTAMP()),
  ('m210307_092657_enhance_consultation_log', UNIX_TIMESTAMP()),
  ('m210425_100105_tag_types_amendment_tags', UNIX_TIMESTAMP()),
  ('m210509_173210_statute_amendments', UNIX_TIMESTAMP()),
  ('m210724_134121_votings', UNIX_TIMESTAMP()),
  ('m211031_004346_failed_login_attempts', UNIX_TIMESTAMP()),
  ('m211108_192545_non_public_motion_sections', UNIX_TIMESTAMP()),
  ('m211218_190505_voting_block_answers_permissions', UNIX_TIMESTAMP()),
  ('m220102_130212_user_groups', UNIX_TIMESTAMP()),
  ('m220116_154835_policy_data', UNIX_TIMESTAMP()),
  ('m220305_160942_voting_quorum', UNIX_TIMESTAMP()),
  ('m220512_074519_voting_position', UNIX_TIMESTAMP()),
  ('m220528_175811_remove_user_privilege_tables', UNIX_TIMESTAMP()),
  ('m220710_080845_remove_odt_templates', UNIX_TIMESTAMP()),
  ('m220710_114056_document_file_groups', UNIX_TIMESTAMP()),
  ('m220730_144556_voting_block_settings_usergroup_order', UNIX_TIMESTAMP()),
  ('m220806_131705_motion_modification_date', UNIX_TIMESTAMP()),
  ('m220902_181010_motion_not_commentable', UNIX_TIMESTAMP()),
  ('m220904_083241_amendment_to_other_amendments', UNIX_TIMESTAMP()),
  ('m221224_151157_remove_site_admins', UNIX_TIMESTAMP()),
  ('m230218_110905_motion_proposal_reference', UNIX_TIMESTAMP()),
  ('m230219_132917_motion_versions', UNIX_TIMESTAMP()),
  ('m230318_132711_hierarchical_tags_with_settings', UNIX_TIMESTAMP()),
  ('m240406_155022_vote_weight', UNIX_TIMESTAMP()),
  ('m240427_090527_motion_status_index', UNIX_TIMESTAMP()),
  ('m240830_181716_user_secret_key', UNIX_TIMESTAMP()),
  ('m241013_105549_pages_files', UNIX_TIMESTAMP()),
  ('m241027_074032_pages_policies', UNIX_TIMESTAMP()),
  ('m241201_100317_background_jobs', UNIX_TIMESTAMP()),
  ('m250608_180000_multiple_proposals', UNIX_TIMESTAMP()),
  ('m250817_080222_date_submission', UNIX_TIMESTAMP()),
  ('m250829_055949_increase_category_length', UNIX_TIMESTAMP()),
  ('m250916_234203_maxLen_not_nullable', UNIX_TIMESTAMP());
EOF

mysql -h "$DB_HOST" -P "${DB_PORT:-3306}" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < "$migration_sql"
rm "$migration_sql"
echo "[init-db] Migrations marked as applied"

# Create default site and consultation
echo "[init-db] Creating default site and consultation..."

# Escape single quotes in variables
SITE_TITLE_ESC=$(echo "$DEFAULT_SITE_TITLE" | sed "s/'/''/g")
SITE_ORG_ESC=$(echo "$DEFAULT_SITE_ORG" | sed "s/'/''/g")
CONSULTATION_TITLE_ESC=$(echo "$DEFAULT_CONSULTATION_TITLE" | sed "s/'/''/g")

# For single-site mode, use fixed 'std' subdomain (referenced in config.json siteSubdomain)
# For multisite mode, use the configured subdomain
if [ "$ANTRAGSGRUEN_MODE" = "single-site" ]; then
    SITE_SUBDOMAIN="std"
    echo "[init-db] Single-site mode: using 'std' subdomain (direct access without subdomain in URL)"
else
    SITE_SUBDOMAIN="$DEFAULT_SITE_SUBDOMAIN"
    echo "[init-db] Multisite mode: using subdomain '$SITE_SUBDOMAIN'"
fi

mysql -h "$DB_HOST" -P "${DB_PORT:-3306}" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" << EOF
-- Create default site
INSERT INTO site (id, subdomain, title, titleShort, dateCreation, settings, currentConsultationId, public, contact, organization, status)
VALUES (
    1,
    '$SITE_SUBDOMAIN',
    '$SITE_TITLE_ESC',
    '$SITE_TITLE_ESC',
    NOW(),
    '{"siteLayout": "layout-classic", "showAntragsgruenAd": false, "loginMethods": [0, 1, 3]}',
    NULL,
    1,
    'Administrator',
    '$SITE_ORG_ESC',
    0
);

-- Create default consultation
INSERT INTO consultation (id, siteId, urlPath, wordingBase, title, titleShort, amendmentNumbering, adminEmail, dateCreation, settings)
VALUES (
    1,
    1,
    '$DEFAULT_CONSULTATION_PATH',
    'en',
    '$CONSULTATION_TITLE_ESC',
    '$CONSULTATION_TITLE_ESC',
    0,
    'admin@example.com',
    NOW(),
    '{"maintenanceMode": false, "screeningMotions": false, "screeningAmendments": false, "lineNumberingGlobal": false, "iniatorsMayEdit": false, "hideTitlePrefix": false, "showFeeds": true, "commentNeedsEmail": false, "screeningComments": false, "initiatorConfirmEmails": false, "adminsMayEdit": true, "forceMotion": null, "editorialAmendments": true, "globalAlternatives": true, "proposalProcedurePage": true, "forceLogin": false, "managedUserAccounts": false, "minimalisticUI": false, "commentsSupportable": false, "screeningMotionsShown": false, "allowMultipleTags": false, "odtExportHasLineNumers": true, "lineLength": 80, "startLayoutType": 0}'
);

-- Link consultation to site
UPDATE site SET currentConsultationId = 1 WHERE id = 1;
EOF

echo "[init-db] Database initialization complete!"
echo "[init-db] Mode: $ANTRAGSGRUEN_MODE"
if [ "$ANTRAGSGRUEN_MODE" = "single-site" ]; then
    echo "[init-db] Site: $DEFAULT_SITE_TITLE (direct access, no subdomain)"
    echo "[init-db] Consultation: $DEFAULT_CONSULTATION_TITLE (path: /$DEFAULT_CONSULTATION_PATH)"
    echo "[init-db] Access at: http://\${DOMAIN}/$DEFAULT_CONSULTATION_PATH"
else
    echo "[init-db] Site: $DEFAULT_SITE_TITLE (subdomain: $DEFAULT_SITE_SUBDOMAIN)"
    echo "[init-db] Consultation: $DEFAULT_CONSULTATION_TITLE (path: /$DEFAULT_CONSULTATION_PATH)"
    echo "[init-db] Access at: http://$DEFAULT_SITE_SUBDOMAIN.\${DOMAIN}/$DEFAULT_CONSULTATION_PATH"
fi

return 0 2>/dev/null || exit 0
