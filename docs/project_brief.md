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
- Multiple users moving or editing the same task. (last write wins)
  - new writes simply overwrite the current details. The later write would therefore win. Could cause issues with changes being lost. considering the scope of the MVP and the target being small teams, it would be an acceptable compromise
  - researching and implementing merging strategies would add complexity and time not desirable at this point, but worth looking into if this project is to be expanded beyond and MVP
- tracking task position in column. (fractional positioning)
  - updating surrounding task would keep position readable in the database, but doesn't really offer any advantages in terms of coding logic while still increasing writes
  - fractional positioning would only require a single write, though position might become harder to read when task are moved often. One can possibly correct this somewhat with some logic when moving.
  - tracking the order in a separate list on the board or elsewhere could also work, but would also result in extra writes
- board removal while on the board
  - all users should be moved to the list view with some sort of notification that the board was removed
  - leaving users on the board would cause confusion (edits wont work) and the board would likely become empty due to data sync
- animating/positioning tasks during drag & drop
  - since positioning is part of the model, simply adding to the end is not an option. This functionality will need to be implemented at some point
  - eventual position should be clear while dragging
    - space opening between tasks
  - dropping near top should position above (first) item and vice versa for the bottom of an item
- owner leaving board
  - board deletion. the board requires an owner for adding and removing members, since there is no way of specific owner change the board will need to be deleted. members active on the board are notified of deletion and returned to list. transfer could be future consideration
- cascading deletion
  - tasks after board deletion
    - since they are part of the board, there is no need for them to remain after it has been deleted and the sub collection should be removed
  - account deletion
    - owned boards are deleted
    - assigned tasks are unassigned
    - removed from member list

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

# Key flows
- Account creation
  - user opens app
  - chooses auth method (email/pass, oAuth, magic link)
  - account is created or authenticated
  - user is logged in and lands no the board list page
    - last active board perhaps a future feature
- board creation
  - from the board list view the user pressing the FAB
  - bottom sheet opens with board form and save/cancel button
    - accepts
      - board gets created showing loading
        - user is moved to new board
      - creation fails
        - bottom sheet closes
        - error notification shown
- board deletion
  - user is on board list view
  - user swipes board sideways showing delete color and icon behind list item
  - confirmation bottom sheet shown 
    - accepts
      - user is owner
        - deletion request sent
          - active users on board are navigated to board list
          - users are shown persistent modal with deletion info
          - users dismissed modal
        - bottom sheet closes
          - deletion fails
          - error notification shown
      - user is member
        - user is removed from the member list of the board
    - cancels
      - bottom sheet is closed
- Member addition
  - user is on a board
  - user selects user icon in app bar
  - member list is shown with search bar
  - user enters username or email
  - list is shown containing non participating users
  - user selects add button besides user
  - selected user is added to the list of members
- Task creation
  - User is on a board
  - user presses the FAB 
  - bottom sheet is opened with task form, cancel/save button
  - user enters task details
    - user saves
      - bottom sheet is closed
      - task is added to first column
      - create endpoint is called with details
    - user cancels
      - bottom sheet is closed
      - changes are lost
- Task movement
  - user is on a board
  - user long presses task
  - task becomes draggable
    - user moves task across columns
      - task is moved to column
      - position is positioned in between other task if dropped there
    - user moves task within column
      - task is positioned in between other dropped tasks
- Task deletion
  - user is on a board
  - user presses a task to open detail bottom sheet
  - user presses delete button at the bottom left
  - confirm modal is shown
    - user accepts
      - bottom sheet is closed
      - task is deleted
      - delete endpoint is called
    - user cancels
      - bottom sheet is closed
- Task editing
  - user is on board
  - user presses task to open detail bottom sheet
  - user presses edit bottom in bottom right
  - same create form is opened with details prefilled
    - user saves
      - user is returned to detail bottom sheet
      - details are updated
      - update endpoint is called
    - user cancels
      - user is returned to detail bottom sheet

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
