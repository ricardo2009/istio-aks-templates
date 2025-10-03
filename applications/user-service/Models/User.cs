using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace UserService.Models;

/// <summary>
/// User entity model for CosmosDB
/// </summary>
public class User
{
    /// <summary>
    /// Unique identifier for the user
    /// </summary>
    [JsonPropertyName("id")]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    /// <summary>
    /// User ID for partitioning in CosmosDB
    /// </summary>
    [JsonPropertyName("userId")]
    public string UserId { get; set; } = string.Empty;

    /// <summary>
    /// User's email address (unique)
    /// </summary>
    [JsonPropertyName("email")]
    [Required]
    [EmailAddress]
    public string Email { get; set; } = string.Empty;

    /// <summary>
    /// User's full name
    /// </summary>
    [JsonPropertyName("name")]
    [Required]
    [StringLength(100, MinimumLength = 2)]
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// Hashed password
    /// </summary>
    [JsonPropertyName("passwordHash")]
    public string PasswordHash { get; set; } = string.Empty;

    /// <summary>
    /// User's role in the system
    /// </summary>
    [JsonPropertyName("role")]
    public UserRole Role { get; set; } = UserRole.Customer;

    /// <summary>
    /// User's current status
    /// </summary>
    [JsonPropertyName("status")]
    public UserStatus Status { get; set; } = UserStatus.Active;

    /// <summary>
    /// User's profile information
    /// </summary>
    [JsonPropertyName("profile")]
    public UserProfile Profile { get; set; } = new();

    /// <summary>
    /// User's preferences
    /// </summary>
    [JsonPropertyName("preferences")]
    public UserPreferences Preferences { get; set; } = new();

    /// <summary>
    /// Security settings
    /// </summary>
    [JsonPropertyName("security")]
    public UserSecurity Security { get; set; } = new();

    /// <summary>
    /// Account creation timestamp
    /// </summary>
    [JsonPropertyName("createdAt")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Last update timestamp
    /// </summary>
    [JsonPropertyName("updatedAt")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Last login timestamp
    /// </summary>
    [JsonPropertyName("lastLoginAt")]
    public DateTime? LastLoginAt { get; set; }

    /// <summary>
    /// Email verification status
    /// </summary>
    [JsonPropertyName("emailVerified")]
    public bool EmailVerified { get; set; } = false;

    /// <summary>
    /// Email verification token
    /// </summary>
    [JsonPropertyName("emailVerificationToken")]
    public string? EmailVerificationToken { get; set; }

    /// <summary>
    /// Password reset token
    /// </summary>
    [JsonPropertyName("passwordResetToken")]
    public string? PasswordResetToken { get; set; }

    /// <summary>
    /// Password reset token expiration
    /// </summary>
    [JsonPropertyName("passwordResetExpires")]
    public DateTime? PasswordResetExpires { get; set; }

    /// <summary>
    /// Document type for CosmosDB
    /// </summary>
    [JsonPropertyName("type")]
    public string Type { get; set; } = "user";

    /// <summary>
    /// Time to live in seconds (for temporary documents)
    /// </summary>
    [JsonPropertyName("ttl")]
    public int? Ttl { get; set; }

    public User()
    {
        UserId = Id;
    }
}

/// <summary>
/// User roles enumeration
/// </summary>
public enum UserRole
{
    Customer = 0,
    Admin = 1,
    Manager = 2,
    Support = 3
}

/// <summary>
/// User status enumeration
/// </summary>
public enum UserStatus
{
    Active = 0,
    Inactive = 1,
    Suspended = 2,
    Deleted = 3,
    PendingVerification = 4
}

/// <summary>
/// User profile information
/// </summary>
public class UserProfile
{
    /// <summary>
    /// First name
    /// </summary>
    [JsonPropertyName("firstName")]
    public string FirstName { get; set; } = string.Empty;

    /// <summary>
    /// Last name
    /// </summary>
    [JsonPropertyName("lastName")]
    public string LastName { get; set; } = string.Empty;

    /// <summary>
    /// Phone number
    /// </summary>
    [JsonPropertyName("phone")]
    public string? Phone { get; set; }

    /// <summary>
    /// Date of birth
    /// </summary>
    [JsonPropertyName("dateOfBirth")]
    public DateTime? DateOfBirth { get; set; }

    /// <summary>
    /// Gender
    /// </summary>
    [JsonPropertyName("gender")]
    public string? Gender { get; set; }

    /// <summary>
    /// Profile picture URL
    /// </summary>
    [JsonPropertyName("avatar")]
    public string? Avatar { get; set; }

    /// <summary>
    /// Bio or description
    /// </summary>
    [JsonPropertyName("bio")]
    public string? Bio { get; set; }

    /// <summary>
    /// Address information
    /// </summary>
    [JsonPropertyName("address")]
    public Address? Address { get; set; }
}

/// <summary>
/// Address information
/// </summary>
public class Address
{
    /// <summary>
    /// Street address
    /// </summary>
    [JsonPropertyName("street")]
    public string Street { get; set; } = string.Empty;

    /// <summary>
    /// City
    /// </summary>
    [JsonPropertyName("city")]
    public string City { get; set; } = string.Empty;

    /// <summary>
    /// State or province
    /// </summary>
    [JsonPropertyName("state")]
    public string State { get; set; } = string.Empty;

    /// <summary>
    /// Postal code
    /// </summary>
    [JsonPropertyName("postalCode")]
    public string PostalCode { get; set; } = string.Empty;

    /// <summary>
    /// Country
    /// </summary>
    [JsonPropertyName("country")]
    public string Country { get; set; } = string.Empty;
}

/// <summary>
/// User preferences
/// </summary>
public class UserPreferences
{
    /// <summary>
    /// Preferred language
    /// </summary>
    [JsonPropertyName("language")]
    public string Language { get; set; } = "en";

    /// <summary>
    /// Preferred currency
    /// </summary>
    [JsonPropertyName("currency")]
    public string Currency { get; set; } = "USD";

    /// <summary>
    /// Timezone
    /// </summary>
    [JsonPropertyName("timezone")]
    public string Timezone { get; set; } = "UTC";

    /// <summary>
    /// Email notifications enabled
    /// </summary>
    [JsonPropertyName("emailNotifications")]
    public bool EmailNotifications { get; set; } = true;

    /// <summary>
    /// SMS notifications enabled
    /// </summary>
    [JsonPropertyName("smsNotifications")]
    public bool SmsNotifications { get; set; } = false;

    /// <summary>
    /// Push notifications enabled
    /// </summary>
    [JsonPropertyName("pushNotifications")]
    public bool PushNotifications { get; set; } = true;

    /// <summary>
    /// Marketing emails enabled
    /// </summary>
    [JsonPropertyName("marketingEmails")]
    public bool MarketingEmails { get; set; } = false;

    /// <summary>
    /// Theme preference
    /// </summary>
    [JsonPropertyName("theme")]
    public string Theme { get; set; } = "light";
}

/// <summary>
/// User security settings
/// </summary>
public class UserSecurity
{
    /// <summary>
    /// Two-factor authentication enabled
    /// </summary>
    [JsonPropertyName("twoFactorEnabled")]
    public bool TwoFactorEnabled { get; set; } = false;

    /// <summary>
    /// Two-factor authentication secret
    /// </summary>
    [JsonPropertyName("twoFactorSecret")]
    public string? TwoFactorSecret { get; set; }

    /// <summary>
    /// Backup codes for two-factor authentication
    /// </summary>
    [JsonPropertyName("backupCodes")]
    public List<string> BackupCodes { get; set; } = new();

    /// <summary>
    /// Failed login attempts count
    /// </summary>
    [JsonPropertyName("failedLoginAttempts")]
    public int FailedLoginAttempts { get; set; } = 0;

    /// <summary>
    /// Account locked until timestamp
    /// </summary>
    [JsonPropertyName("lockedUntil")]
    public DateTime? LockedUntil { get; set; }

    /// <summary>
    /// Last password change timestamp
    /// </summary>
    [JsonPropertyName("lastPasswordChange")]
    public DateTime LastPasswordChange { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Login sessions
    /// </summary>
    [JsonPropertyName("sessions")]
    public List<UserSession> Sessions { get; set; } = new();
}

/// <summary>
/// User session information
/// </summary>
public class UserSession
{
    /// <summary>
    /// Session ID
    /// </summary>
    [JsonPropertyName("id")]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    /// <summary>
    /// Device information
    /// </summary>
    [JsonPropertyName("device")]
    public string Device { get; set; } = string.Empty;

    /// <summary>
    /// IP address
    /// </summary>
    [JsonPropertyName("ipAddress")]
    public string IpAddress { get; set; } = string.Empty;

    /// <summary>
    /// User agent
    /// </summary>
    [JsonPropertyName("userAgent")]
    public string UserAgent { get; set; } = string.Empty;

    /// <summary>
    /// Session creation timestamp
    /// </summary>
    [JsonPropertyName("createdAt")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Last activity timestamp
    /// </summary>
    [JsonPropertyName("lastActivity")]
    public DateTime LastActivity { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Session expiration timestamp
    /// </summary>
    [JsonPropertyName("expiresAt")]
    public DateTime ExpiresAt { get; set; } = DateTime.UtcNow.AddDays(30);

    /// <summary>
    /// Session is active
    /// </summary>
    [JsonPropertyName("isActive")]
    public bool IsActive { get; set; } = true;
}
