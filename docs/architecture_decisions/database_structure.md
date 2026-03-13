# Firebase collection structure
- Users
  - uuid (pk)
  - email text (unique)
  - name text
- Boards
  - uuid (pk)
  - ownerUuid (fk to user.uuid)
  - name text
  - members list(fk user.uuid)
  - Tasks (subcollection)
    - uuid (pk)
    - title text
    - description text
    - column enum(todo, blocked, inProgress, inReview, done)
    - position int
    - assigneeUuid (fk user.uuid)

## Relations
- User 0:* Board
- Board 1 User (owner)
- Board 1:* User (members)
- Board 0:* Task
- Task 1 Board