import Foundation

struct CountryCode: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let code: String
    let flag: String
    
    static let countries: [CountryCode] = [
        CountryCode(id: "US", name: "United States", code: "+1", flag: "🇺🇸"),
        CountryCode(id: "IN", name: "India", code: "+91", flag: "🇮🇳"),
        CountryCode(id: "GB", name: "United Kingdom", code: "+44", flag: "🇬🇧"),
        CountryCode(id: "CA", name: "Canada", code: "+1", flag: "🇨🇦"),
        CountryCode(id: "AU", name: "Australia", code: "+61", flag: "🇦🇺"),
        CountryCode(id: "DE", name: "Germany", code: "+49", flag: "🇩🇪"),
        CountryCode(id: "FR", name: "France", code: "+33", flag: "🇫🇷"),
        CountryCode(id: "IT", name: "Italy", code: "+39", flag: "🇮🇹"),
        CountryCode(id: "ES", name: "Spain", code: "+34", flag: "🇪🇸"),
        CountryCode(id: "BR", name: "Brazil", code: "+55", flag: "🇧🇷"),
        CountryCode(id: "MX", name: "Mexico", code: "+52", flag: "🇲🇽"),
        CountryCode(id: "JP", name: "Japan", code: "+81", flag: "🇯🇵"),
        CountryCode(id: "CN", name: "China", code: "+86", flag: "🇨🇳"),
        CountryCode(id: "KR", name: "South Korea", code: "+82", flag: "🇰🇷"),
        CountryCode(id: "RU", name: "Russia", code: "+7", flag: "🇷🇺"),
        CountryCode(id: "SA", name: "Saudi Arabia", code: "+966", flag: "🇸🇦"),
        CountryCode(id: "AE", name: "UAE", code: "+971", flag: "🇦🇪"),
        CountryCode(id: "SG", name: "Singapore", code: "+65", flag: "🇸🇬"),
        CountryCode(id: "MY", name: "Malaysia", code: "+60", flag: "🇲🇾"),
        CountryCode(id: "TH", name: "Thailand", code: "+66", flag: "🇹🇭"),
        CountryCode(id: "ID", name: "Indonesia", code: "+62", flag: "🇮🇩"),
        CountryCode(id: "PH", name: "Philippines", code: "+63", flag: "🇵🇭"),
        CountryCode(id: "VN", name: "Vietnam", code: "+84", flag: "🇻🇳"),
        CountryCode(id: "NZ", name: "New Zealand", code: "+64", flag: "🇳🇿"),
        CountryCode(id: "ZA", name: "South Africa", code: "+27", flag: "🇿🇦"),
        CountryCode(id: "EG", name: "Egypt", code: "+20", flag: "🇪🇬"),
        CountryCode(id: "NG", name: "Nigeria", code: "+234", flag: "🇳🇬"),
        CountryCode(id: "KE", name: "Kenya", code: "+254", flag: "🇰🇪"),
        CountryCode(id: "AR", name: "Argentina", code: "+54", flag: "🇦🇷"),
        CountryCode(id: "CL", name: "Chile", code: "+56", flag: "🇨🇱"),
        CountryCode(id: "CO", name: "Colombia", code: "+57", flag: "🇨🇴"),
        CountryCode(id: "PE", name: "Peru", code: "+51", flag: "🇵🇪"),
        CountryCode(id: "PK", name: "Pakistan", code: "+92", flag: "🇵🇰"),
        CountryCode(id: "BD", name: "Bangladesh", code: "+880", flag: "🇧🇩"),
        CountryCode(id: "LK", name: "Sri Lanka", code: "+94", flag: "🇱🇰"),
        CountryCode(id: "NP", name: "Nepal", code: "+977", flag: "🇳🇵"),
        CountryCode(id: "TR", name: "Turkey", code: "+90", flag: "🇹🇷"),
        CountryCode(id: "IL", name: "Israel", code: "+972", flag: "🇮🇱"),
        CountryCode(id: "PL", name: "Poland", code: "+48", flag: "🇵🇱"),
        CountryCode(id: "NL", name: "Netherlands", code: "+31", flag: "🇳🇱"),
        CountryCode(id: "BE", name: "Belgium", code: "+32", flag: "🇧🇪"),
        CountryCode(id: "CH", name: "Switzerland", code: "+41", flag: "🇨🇭"),
        CountryCode(id: "AT", name: "Austria", code: "+43", flag: "🇦🇹"),
        CountryCode(id: "SE", name: "Sweden", code: "+46", flag: "🇸🇪"),
        CountryCode(id: "NO", name: "Norway", code: "+47", flag: "🇳🇴"),
        CountryCode(id: "DK", name: "Denmark", code: "+45", flag: "🇩🇰"),
        CountryCode(id: "FI", name: "Finland", code: "+358", flag: "🇫🇮"),
        CountryCode(id: "IE", name: "Ireland", code: "+353", flag: "🇮🇪"),
        CountryCode(id: "PT", name: "Portugal", code: "+351", flag: "🇵🇹"),
        CountryCode(id: "GR", name: "Greece", code: "+30", flag: "🇬🇷"),
        CountryCode(id: "CZ", name: "Czech Republic", code: "+420", flag: "🇨🇿"),
        CountryCode(id: "HU", name: "Hungary", code: "+36", flag: "🇭🇺"),
        CountryCode(id: "RO", name: "Romania", code: "+40", flag: "🇷🇴"),
    ]
    
    static func getDefault() -> CountryCode {
        // Try to get device locale, default to US
        if let regionCode = Locale.current.region?.identifier,
           let country = countries.first(where: { $0.id == regionCode }) {
            return country
        }
        return countries.first(where: { $0.id == "US" }) ?? countries[0]
    }
    
    static func findByCode(_ code: String) -> CountryCode? {
        return countries.first(where: { $0.code == code })
    }
}

