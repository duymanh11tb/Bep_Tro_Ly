import pymysql, ssl
ctx = ssl.create_default_context()
conn = pymysql.connect(
    host='gateway01.ap-southeast-1.prod.aws.tidbcloud.com',
    port=4000, user='2p1kPkGWJhFrKpg.root',
    password='qmb8dm6ODyQbnzhw', database='Bep_Tro_Ly',
    ssl=ctx
)
cur = conn.cursor()
cur.execute("DESCRIBE users")
with open('db_schema.txt', 'w') as f:
    f.write("=== USERS TABLE ===\n")
    for row in cur.fetchall():
        f.write(f"{row[0]:25s} | {str(row[1]):30s} | null={row[2]} | key={row[3]} | default={row[4]}\n")
    cur.execute("SELECT user_id, email, LEFT(password_hash,30), notification_time FROM users LIMIT 5")
    f.write("\n=== EXISTING USERS ===\n")
    for row in cur.fetchall():
        f.write(f"id={row[0]} email={row[1]} hash={row[2]} notif_time={row[3]}\n")
conn.close()
print("Done! Check db_schema.txt")
