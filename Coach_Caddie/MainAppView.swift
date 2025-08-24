import SwiftUI
import FirebaseAuth

// MARK: - Main App View (Uses your existing ContentView)
struct MainAppView: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @EnvironmentObject var teamManager: TeamManager
    @EnvironmentObject var firebaseManager: FirebaseManager
    
    var body: some View {
        TabView {
            // Use your existing enhanced ContentView
            ContentView()
                .environmentObject(teamManager)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            TeamsListView()
                .environmentObject(teamManager)
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Teams")
                }
            
            Text("Stats Coming Soon")
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Stats")
                }
            
            Text("Calendar Coming Soon")
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Calendar")
                }
            
            ProfileView()
                .environmentObject(authManager)
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text("Profile")
                }
        }
        .accentColor(.green)
    }
}

// MARK: - Simple Teams List View
struct TeamsListView: View {
    @EnvironmentObject var teamManager: TeamManager
    @State private var showingNewTeam = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(teamManager.teams) { team in
                    NavigationLink(destination: TeamDetailView(team: Binding(
                        get: { team },
                        set: { _ in }
                    ), teamManager: teamManager)) {
                        VStack(alignment: .leading) {
                            Text(team.name)
                                .font(.headline)
                            Text("\(team.players.count) players")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Teams")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewTeam = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewTeam) {
                NewTeamView(teamManager: teamManager)
            }
        }
    }
}

// MARK: - Simple Profile View
struct ProfileView: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let coach = authManager.currentCoach {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text(coach.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(coach.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Sign Out") {
                        authManager.signOut()
                    }
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .navigationTitle("Profile")
            .padding()
        }
    }
}

// MARK: - Authentication View
struct AuthenticationView: View {
    @ObservedObject var authManager: FirebaseAuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var name = ""
    @State private var phone = ""
    @State private var confirmPassword = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // App Logo
                VStack(spacing: 16) {
                    Image(systemName: "sportscourt.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Coach Caddie")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("Team Management Made Easy")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // Form
                VStack(spacing: 16) {
                    if isSignUp {
                        TextField("Full Name", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        TextField("Phone Number", text: $phone)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.phonePad)
                    }
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if isSignUp {
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Error Message
                    if let error = authManager.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    // Submit Button
                    Button(action: submitForm) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            Text(isSignUp ? "Sign Up" : "Sign In")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                    
                    // Toggle Sign Up/Sign In
                    Button(action: { isSignUp.toggle() }) {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
    }
    
    private func submitForm() {
        Task {
            if isSignUp {
                await authManager.signUp(
                    name: name,
                    email: email,
                    phone: phone,
                    password: password,
                    confirmPassword: confirmPassword
                )
            } else {
                await authManager.signIn(email: email, password: password)
            }
        }
    }
}

// MARK: - Placeholder Classes (Add these if they don't exist)
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    private init() {}
    
    func requestPermission() {
        // Basic implementation
        print("Notification permission requested")
    }
}

class AppStateManager: ObservableObject {
    @Published var isOffline = false
    @Published var pendingSyncItems = 0
    
    func triggerSync() {
        // Basic implementation
        print("Sync triggered")
    }
}