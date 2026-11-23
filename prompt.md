
# 1. Reference Image Extraction and Preparation
Generate all images in jpg format inside this pdf and name each screen image name with the name provided.


# 2. Project Requirements and Technical Architecture
I want to build Sociao, a modern, mobile-first social media application using Flutter and Supabase. First, inspect the existing VS Code project structure, dependencies, coding patterns, imports and all available screen reference images. Study the images carefully to understand the UI, layout, navigation, components and interactions. Create a comprehensive CLAUDE.md file that will serve as the primary development guide for the entire application. Do not start coding yet. Use Flutter (Dart) for the frontend and Supabase for the backend. Do not introduce a different frontend or backend technology.
Important existing project conventions:
	• The project currently uses material_ui imports, not material.dart. Preserve the existing material_ui import style and UI conventions throughout development. Do not replace them with material.dart or migrate the existing UI approach without my explicit permission.
	• Use Riverpod for state management and go_router for navigation and routing. Keep the architecture modular and consistent.
	• Inspect the existing .gitignore. It currently covers .env*; add env.json explicitly so it is also excluded from Git. Never commit credentials or secrets.
	• There is no reference image for the Create Post screen. Design it yourself using the same visual language, components, spacing, typography, colours and interaction patterns as the other supplied screens. It should look like a natural part of Sociao.
The application should include these features and screens:
	• Authentication: Login, Create Account, email/password validation, show/hide password, logout and protected routes. Use Supabase Auth for authentication and secure password management.
	• Home Feed: Stories with Add Story and Live indicators, user posts with images/videos, likes, comments, bookmarks, sharing, post options, notifications and messages.
	• Video Viewer: Full-screen videos, creator information, captions, music information, like, comment, share and save actions.
	• Comments: Bottom-sheet interface, comments, one-level replies, likes and comment input.
	• Messages: Inbox with profile pictures, names, last-message previews, timestamps and unread indicators; individual chat screens with messages, timestamps, heart reactions and message input.
	• User Profile: Profile photo, name, username, bio, website, post/follower/following counts, Posts and Videos tabs, video grid and Tags tab.
	• Create Post: A well-designed screen for selecting images/videos, previewing media, entering captions and publishing posts. Match the existing Sociao design system.
	• Other screens: Edit Profile, Settings (theme, notifications, language, help and logout), Followers and Following lists with search.
	• Navigation: Bottom navigation with Home, Video, Create (+), Inbox and Profile.
Technology and backend requirements: Build the frontend using Flutter and Dart, following a clean, modular and maintainable architecture. Use the official supabase_flutter package to connect the Flutter application to Supabase. Use Riverpod for state management and go_router for navigation, including authentication-aware route protection. Use Supabase Auth for user registration, login, sessions and logout; Supabase PostgreSQL for persistent application data; Supabase Storage for profile pictures, post images, stories and videos; and Supabase Realtime for messaging and other features requiring live updates. Design appropriate database tables, relationships, indexes and constraints for profiles, posts, likes, comments, stories, follows and messages. Implement Row Level Security (RLS) policies to protect user data and control read/write access. Never hard-code application content except for database seed data. Seed the database with at least 5 users and 10 posts. Likes and unlikes must update the database, display accurate counts after refresh and prevent duplicate likes. Include loading, empty and error states.
Prioritise implementation in this order: (1) Supabase setup, authentication, database, seed data and functional Home Feed with persistent likes; (2) User Profile with real user data and posts; (3) Video Viewer and Comments; (4) Messages and Chat; (5) Create Post, navigation, Settings, Edit Profile, Followers and Following. Ensure the UI closely follows the supplied reference images while remaining responsive, consistent and user-friendly.
The CLAUDE.md must contain the Flutter and Supabase architecture, recommended folder structure, required dependencies, database schema, Supabase integration approach, storage bucket organisation, RLS security policies, Riverpod state management approach, go_router navigation strategy, UI guidelines, coding standards, implementation phases and testing instructions. Explicitly document the existing material_ui convention and instruct Claude Code to preserve it. Include Flutter setup and run commands, Supabase project configuration, environment variable requirements, database migration and seed instructions, and instructions for safely managing Supabase keys. Ensure .gitignore excludes .env* and env.json. Clearly distinguish the Supabase publishable/anon key from the secret service-role key; never expose the service-role key in the Flutter application. Add a feature checklist to track development progress. Keep the instructions practical, specific and easy for Claude Code to follow. Avoid unnecessary complexity and prioritise clean, modular, reusable and maintainable code.
Your immediate task is to generate CLAUDE.md only. Do not implement the application until I explicitly ask you to proceed.

# 3. Screen Reference Integration
I have pasted the screen images sequentially inside reference folder. Please refer to it and continue the earlier prompt.

# 4. Supabase Configuration and Database Migration
I pasted the url and key into env.json. Run migrations with the supabase CLI.

# 5. Email Authentication Configuration
I have successfully turned off the confirm email for development.

# 6. Supabase Project Linking
Finished Supabase Link.

# 7. Database Seeding and Sample Data Setup
Seed this project.

# 8. Feature Verification and Missing Functionality Investigation
Sign out: this is on the Settings screen, reachable from the Profile tab's gear icon. The other Settings rows are laid out but only show "Coming soon". 
Home Feed: Header with notification and chat buttons, a stories row, and post cards. Likes update instantly, then reconcile with the database and roll back if the request fails. Bookmark, share and the options menu work. Pull-to-refresh, paging, and loading, empty and error states are in. Please look into the above. 
I cant find these.

# 9. Remaining Feature Implementation, Testing and Completion
Share current progress and todos. I want you to build all the remaining features and required screens. Once done test them and let me know when done.



