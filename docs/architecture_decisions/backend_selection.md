# Requirements
- The main requirement for a suitable backend is the ability for real-time updates. When a task is added or moved, all members of a board will need to be able to see this change as it happens.
- There needs to be functionality for handling user authentication.
- While not necessarily relational, the database will need to be able to support some form of relations between models

# Options considered
- Firebase
- Supabase

## Firebase
- Firebase's firestore uses NoSQL type storage for their documents.
- Comes with easy authentication and user handling.
- Built from the start with real-time data in mind
- though NoSQL, through the use of queries and firebase rules, relations can be implemented
  
cons
- Cloud based only

## Supabase
- Stores data in a PostgreSQL database, allowing for easier migration of data to different platforms or solutions
- Comes with open source auth for user handling
- supports real-time data via websockets
- relational database is perfect for model relations

cons
- Real-time data is addon, requiring extra setup
- less experience with the framework, requiring extra ramp up time for learning

# Decision
While both platforms have the functionality required to serve as a backend, with its real-time data first approach and the existing knowledge with the platform, Firebase is a better fit for this project.
Although supabase supports similar data synchronization, it's an addon rather than integrated. This would have to be a custom implementation for supabase, increasing development time. 
Being created by the same company, Firebase is also very well integrated with Flutter and easy to setup and manage.

Firebase will therefore be used as the backend implementation.