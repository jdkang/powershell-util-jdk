Storing credentials on a system using the modern [PasswordVault API](https://stackoverflow.com/questions/9052482/best-practice-for-saving-sensitive-data-in-windows-8) system (Windows 8/2012+) in lieu of the older Credential Manager or the [DPAPI](https://stackoverflow.com/questions/6982236/how-is-securestring-encrypted-and-still-usable) (`SecureString`).

Note that any application running under the user's context can access the entireity of the vault. This is by no means a replacement for centralized credential storage, e.g. [Secret Server](https://thycotic.com/products/secret-server/) or [HashiCorp Vault](https://www.vaultproject.io/), [etc](https://coderanger.net/chef-secrets/).

