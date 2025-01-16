#!/bin/bash

MYSQL="./mysql.sh"

if [ $# -ne 2 ]; then
    echo "Usage: $0 result_file.txt database_name"
    exit 1
fi

RESULT_FILE="$1"
DB_NAME="$2"
TABLE_NAME="blacklist_${DB_NAME}"

echo "Processing false positives for database ${DB_NAME}..."

# Extract INSEE IDs into a temporary file and count them
temp_ids="/tmp/insee_ids_$$.txt"
grep -o 'IdInsee([0-9]\+)' "$RESULT_FILE" | sed 's/IdInsee(\([0-9]*\))/\1/' > "$temp_ids"

if [ ! -s "$temp_ids" ]; then
    echo "No IdInsee numbers found in $RESULT_FILE"
    rm -f "$temp_ids"
    exit 1
fi

# Compte le nombre d'IDs trouvés
insee_count=$(wc -l < "$temp_ids")
echo "Found $insee_count IdInsee number(s) in $RESULT_FILE"

# Create SQL commands file with explicit output formatting
sql_commands="/tmp/insee_commands_$$.sql"
cat << EOF > "$sql_commands"
-- Create table if it doesn't exist
CREATE TABLE IF NOT EXISTS \`${TABLE_NAME}\` (
    \`Id\` INTEGER UNSIGNED auto_increment primary key,
    \`TodoKey\` VARCHAR(255) NOT NULL COMMENT 'Combination of key fields to ensure uniqueness',
    \`IdInsee\` INTEGER UNSIGNED NOT NULL,
    \`CreatedAt\` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY \`uk_todo_insee\` (\`TodoKey\`, \`IdInsee\`),
    KEY \`idx_insee\` (\`IdInsee\`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Create and populate temporary table
CREATE TEMPORARY TABLE tmp_insee_ids (IdInsee INTEGER UNSIGNED NOT NULL PRIMARY KEY);

LOAD DATA LOCAL INFILE '${temp_ids}'
INTO TABLE tmp_insee_ids
(IdInsee);

-- Store initial count and perform insertion with explicit count of affected rows
SET @initial_count = (SELECT COUNT(*) FROM \`${TABLE_NAME}\`);

INSERT IGNORE INTO \`${TABLE_NAME}\` (TodoKey, IdInsee)
SELECT DISTINCT
    CONCAT(t.Nom, '|', t.Prenom, '|', t.Sexe, '|',
           t.NaissanceY, t.NaissanceM, t.NaissanceD, '|', 
           t.NaissancePlace, '|',
           t.DecesY, t.DecesM, t.DecesD, '|', 
           t.DecesPlace) as TodoKey,
    t.IdInsee
FROM TODO t
JOIN tmp_insee_ids i ON t.IdInsee = i.IdInsee
LEFT JOIN \`${TABLE_NAME}\` b ON 
    b.TodoKey = CONCAT(t.Nom, '|', t.Prenom, '|', t.Sexe, '|',
                      t.NaissanceY, t.NaissanceM, t.NaissanceD, '|', 
                      t.NaissancePlace, '|',
                      t.DecesY, t.DecesM, t.DecesD, '|', 
                      t.DecesPlace)
    AND b.IdInsee = t.IdInsee
WHERE b.Id IS NULL;

-- Return results in a simple numeric format without column headers
SELECT CONCAT_WS(',',
    (SELECT COUNT(*) FROM \`${TABLE_NAME}\`),
    ROW_COUNT()
) as result;

DROP TEMPORARY TABLE tmp_insee_ids;
EOF

# Execute SQL and capture the results
# The query now returns a single line with comma-separated values
result=$($MYSQL -N < "$sql_commands")

# Parse the results using IFS
IFS=',' read -r total_count added_count <<< "$result"

# Validate that we got numeric values
if ! [[ "$total_count" =~ ^[0-9]+$ ]] || ! [[ "$added_count" =~ ^[0-9]+$ ]]; then
    echo "Error: Failed to get valid counts from database"
    rm -f "$temp_ids" "$sql_commands"
    exit 1
fi

# Format the output message
if [ "$added_count" -eq 0 ]; then
    echo "Blacklist contains $total_count entries (no new entries added)"
else
    echo "Blacklist now contains $total_count entries ($added_count new)"
fi

# Cleanup temporary files
rm -f "$temp_ids" "$sql_commands"