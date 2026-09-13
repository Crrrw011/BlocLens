export const en = {
  metadata: {
    operationsTitle: "BlocLens Operations",
  },
  auth: {
    accessDenied: {
      title: "Access denied",
      body: "Your account is not an active BlocLens Operations staff account.",
      signOut: "Sign out",
    },
    forgotPassword: {
      title: "Reset your password",
      body: "Enter your email address and we will send reset instructions if the account is eligible.",
      emailLabel: "Email address",
      emailPlaceholder: "name@example.com",
      submit: "Send reset instructions",
      success: "If an eligible account uses that address, reset instructions are on their way.",
      backToSignIn: "Back to sign in",
    },
    signIn: {
      title: "Sign in to BlocLens Operations",
      emailLabel: "Email address",
      emailPlaceholder: "name@example.com",
      passwordLabel: "Password",
      submit: "Sign in",
      forgotPassword: "Forgot password?",
      invalidCredentials: "Unable to sign in with those credentials.",
    },
    updatePassword: {
      title: "Choose a new password",
      body: "Set a new password for your BlocLens Operations account.",
      passwordLabel: "New password",
      passwordConfirmationLabel: "Confirm new password",
      submit: "Update password",
      confirmationMismatch: "Passwords must match.",
      invalidPassword: "Use a password with at least 12 characters.",
      requestNewLink: "Unable to update your password. Request a new reset link.",
    },
    portal: {
      title: "Overview",
      signOut: "Sign out",
    },
  },
  shell: {
    brandLabel: "BlocLens Operations",
    primaryNavigation: "Primary navigation",
    destinations: {
      overview: "Overview",
      review: "Review",
      climbingData: "Climbing Data",
      peopleAccess: "People and Access",
      audit: "Audit",
      configuration: "Configuration",
    },
    notifications: "Notifications",
    noNotifications: "No new notifications",
    accountMenu: "Open account menu",
    accountRole: "Staff role",
    roles: {
      admin: "Administrator",
      moderator: "Moderator",
    },
    search: {
      label: "Search operations",
      placeholder: "Search cases, routes or gyms",
      shortcut: "Command K",
    },
    closeDetails: "Close details",
    narrowMode: "Single-item review only on this screen size",
    overviewWorkspace: "Overview workspace",
  },
  states: {
    loading: "Loading",
    empty: {
      title: "Nothing to show",
      body: "Try changing the current filters.",
    },
    error: {
      title: "Unable to load this view",
      body: "Try again. If the problem continues, report it to an Administrator.",
      retry: "Try again",
    },
  },
} as const;
