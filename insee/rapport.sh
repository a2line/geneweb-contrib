#!/bin/bash
# rapport.sh

MYSQL=./mysql.sh

# Optional database name parameter
DB_NAME="$1"

$MYSQL -N << EOF

SELECT concat( Cle, '\n', concat_ws( '|',
    Nom, Prenom, Sexe,
    concat( '°', NaissanceD, '/', NaissanceM, '/', NaissanceY),
    NaissancePlace,
    concat( '+', DecesD, '/', DecesM, '/', DecesY),
    DecesPlace ), '\n', Msg, '\nIdInsee(', IdInsee, ') Score ', Score, ' État ', Etat, '\n')
FROM TODO
WHERE (Etat = 2 and (NaissanceY <> '0000' or DecesY <> '0000'))
   or (Etat = -2 and score > 2)
   or (Etat = -5 and score = 1 or score = 0)
$([ ! -z "$DB_NAME" ] && echo "AND NOT EXISTS (
    SELECT 1 FROM \`blacklist_${DB_NAME}\` b 
    WHERE b.IdInsee = TODO.IdInsee
    AND b.TodoKey = CONCAT(TODO.Nom, '|', TODO.Prenom, '|', TODO.Sexe, '|',
                          TODO.NaissanceY, TODO.NaissanceM, TODO.NaissanceD, '|', 
                          TODO.NaissancePlace, '|',
                          TODO.DecesY, TODO.DecesM, TODO.DecesD, '|', 
                          TODO.DecesPlace)
)")
ORDER BY score desc;
EOF
