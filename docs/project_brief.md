# Overview
This project seeks to create a minimal MVP for a collaborative kanban board users and/or small teams can use to track tasks for a given project. It aims to remain simple, focussing on the primary goal of a kanban board: tracking the status of multiple tasks within the scope of a project.
The user should be able to quickly create a board and start making tasks.

# Non functional expectations
The MVP is targeting smaller teams (1-6) with smaller projects (<100 tasks). Its simplicity provides an easy and quick way to start a project, but lacks the features to support larger or more structured teams.

# Scope
The core features of this app are:
- List of boards created by the user or ones they are members of
  - Creation of new boards
  - Has a title
  - Board deletion/leaving
- A project board featuring multiple columns representing the lifetime of a task
  - Adding and removal of users to collaborate with
  - Columns are hardcoded in the board itself and are fixed values for this MVP in the following order
    - Todo, Blocked, In progress, In review, Done
- Cards representing tasks which can be moved between the different columns on the board
  - Creation and editing of cards
  - Has a title and description
  - Can be rearranged within a column
  - Users can assign themselves to a task
- User authentication for tracking user projects and enabling collaboration between users
  - Managing is done by the creator of the board
  - User can set a name on creation
  - Account deletion
- Real-time updates of changes to a board for all members

# Out of scope
- Auditing
  - Full fledged auditing of task lifetime, board management would add a considerable amount off work, too much for an MVP.
- Tagging
  - The cards and process should be as simple as possible. Projects where tagging would become required are outside the target audience
- Comments
  - While a nice feature to have for collaboration, it is not required to meet the main goal of the project: task tracking.
- Time tracking
  - Like comments, not part of the main goal. Also adds complexity that is unwanted at this stage.
- Card movement validation
  - Complex validation and the configuration of it adds too much complexity. Because the columns are constant and limited, any mistakes are more easiliy corrected. Freedom is also not limited
- Column editing/creation
  - Setup should be as simple as possible. You can start creating and moving task as soon as you create a board.
- User details beyond name
  - Information beyond the identification of a user is at this point not useful
- Backlog
  - All tasks should live inside the project board. No navigation between screens. Keep the user focused on the board
- Board invitations
  - Users are immediately added to the board rather than going through a invitation flow in the interest of simplicity.
- Endpoint retry mechanics
  - To keep the MVP simple and minimal, no mechanisms will be added to handle API failures for eg. creation requests. No internet connection is already handled by firebase caching. If requests end up failing, the initial local action will be reverted (new task deleted, task moved back, deleted board reappears). The user should be informed by notification of the failure
- assigning others
  - No user management features are intended in this MVP beyond the addition and removal of members to a board
- fuzzy user search
  - Too much added complexity, limit to exact match
  - could be added in the future through separate service handling indexing and search requests

# Known complexities
- Multiple users moving or editing the same task (see design document for trade-off analysis)
- Tracking task position in column (see design document for trade-off analysis)
- Board removal while on the board (see design document for approach)
- Animating/positioning tasks during drag & drop (see design document for approach)
- Owner leaving board (see design document for approach)
- Cascading deletion (see design document for approach)

# Entities
- User
  - Details
    - email address
    - name
  - Relations
    - Owns 0 or more boards
    - Is a member of 0 or more boards
- Project board
  - Details
    - Title
    - Columns
      - Todo
      - Blocked
      - In progress
      - In review
      - Done
  - Relations
    - Has 1 owner
    - Has 0 or more tasks
    - Has 1 or more board members
- Board member
  - Details
    - Board
    - User
  - Relations
    - Is part of 1 board
- Task
  - Details
    - Title
    - Description
    - Assignee
    - Position
    - Column
  - Relations
    - Is part of 1 board
    - Has 0 or 1 Board member

# Authorization model
|feature|Owner|Member|
|-------|-----|------|
|add member|✔|x|
|remove member|✔|x|
|delete board|✔|x|
|leave board|✔|✔|
|create task|✔|✔|
|move task|✔|✔|
|edit task|✔|✔|
|remove task|✔|✔|
