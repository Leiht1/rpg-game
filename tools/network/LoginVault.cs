using System;
using System.Text;
using System.Security.Cryptography;
class LoginVault {
    static int Main(string[] args) {
        try {
            byte[] input = Convert.FromBase64String(Console.ReadLine());
            byte[] entropy = Encoding.UTF8.GetBytes("Windrest.Login.v1");
            byte[] result = args.Length == 1 && args[0] == "protect"
                ? ProtectedData.Protect(input, entropy, DataProtectionScope.CurrentUser)
                : ProtectedData.Unprotect(input, entropy, DataProtectionScope.CurrentUser);
            Console.WriteLine(Convert.ToBase64String(result));
            return 0;
        } catch { return 1; }
    }
}
