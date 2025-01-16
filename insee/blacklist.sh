#!/bin/bash
# blacklist.sh

MYSQL="./mysql.sh"
BACKUP_DIR="blacklist_backups"

usage() {
    echo "Usage:"
    echo "  Backup:  $0 backup database_name"
    echo "  Restore: $0 restore database_name backup_file"
    echo ""
    echo "Examples:"
    echo "  $0 backup mydatabase"
    echo "  $0 restore mydatabase $BACKUP_DIR/blacklist_mydatabase_20240116_120000.sql"
    exit 1
}

# Check minimum arguments
if [ $# -lt 2 ]; then
    usage
fi

ACTION="$1"
DB_NAME="$2"
TABLE_NAME="blacklist_${DB_NAME}"

case "$ACTION" in
    backup)
        mkdir -p "$BACKUP_DIR"
        BACKUP_FILE="${BACKUP_DIR}/${TABLE_NAME}_$(date +%Y%m%d_%H%M%S).sql"
        
        echo "Creating backup of $TABLE_NAME..."
        
        # Check if table exists
        TABLE_EXISTS=$($MYSQL -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = '${TABLE_NAME}';")
        if [ "$TABLE_EXISTS" -eq 0 ]; then
            echo "Error: Table ${TABLE_NAME} does not exist!"
            exit 1
        fi

        # Export table structure and data
        $MYSQL -N -B << EOF > "$BACKUP_FILE"
-- Backup created $(date '+%Y-%m-%d %H:%M:%S')
DROP TABLE IF EXISTS \`${TABLE_NAME}\`;
$(mysql -N -B -e "SHOW CREATE TABLE \`${TABLE_NAME}\`;" | awk 'NR==1 {print $2}')

SELECT CONCAT('INSERT INTO \`${TABLE_NAME}\` (TodoKey, IdInsee) VALUES (\'', 
       REPLACE(TodoKey, '\'', '\\\''), '\', ', IdInsee, ');')
FROM \`${TABLE_NAME}\`;
EOF
        
        echo "Backup created: $BACKUP_FILE"
        echo "Number of records: $($MYSQL -N -e "SELECT COUNT(*) FROM \`${TABLE_NAME}\`;")"
        ;;
        
    restore)
        if [ $# -ne 3 ]; then
            echo "Error: Backup file parameter missing for restore operation"
            usage
        fi
        
        BACKUP_FILE="$3"
        
        if [ ! -f "$BACKUP_FILE" ]; then
            echo "Error: Backup file $BACKUP_FILE not found!"
            exit 1
        }
        
        echo "Restoring $TABLE_NAME from $BACKUP_FILE..."
        
        # Restore from backup
        $MYSQL < "$BACKUP_FILE"
        
        if [ $? -eq 0 ]; then
            echo "Restore completed successfully"
            echo "Number of records: $($MYSQL -N -e "SELECT COUNT(*) FROM \`${TABLE_NAME}\`;")"
        else
            echo "Error during restore!"
            exit 1
        fi
        ;;
        
    *)
        echo "Error: Invalid action '$ACTION'"
        usage
        ;;
esac