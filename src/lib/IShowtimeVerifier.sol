// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

struct Attestation {
    address beneficiary;
    address context;
    uint256 nonce;
    uint256 validUntil;
}

struct SignedAttestation {
    Attestation attestation;
    bytes signature;
}

// Vendored from:
// https://github.com/showtime-xyz/showtime-contracts-v2/blob/173bba71afd6b032874774f92b55d1c053cf386e/src/interfaces/IShowtimeVerifier.sol
interface IShowtimeVerifier {
    error BadNonce(uint256 expected, uint256 actual);
    error DeadlineTooLong();
    error Expired();
    error NullAddress();
    error SignerExpired(address signer);
    error Unauthorized();
    error UnknownSigner();

    event SignerAdded(address signer, uint256 validUntil);
    event SignerRevoked(address signer);
    event ManagerUpdated(address newManager);

    function nonces(address) external view returns (uint256);

    function verify(SignedAttestation calldata signedAttestation) external view returns (bool);

    function verifyAndBurn(SignedAttestation calldata signedAttestation) external returns (bool);

    function verify(
        Attestation calldata attestation,
        bytes32 typeHash,
        bytes memory encodedData,
        bytes calldata signature
    ) external view returns (bool);

    function verifyAndBurn(
        Attestation calldata attestation,
        bytes32 typeHash,
        bytes memory encodedData,
        bytes calldata signature
    ) external returns (bool);

    function setManager(address _manager) external;

    function registerSigner(address signer, uint256 validityDays) external returns (uint256 validUntil);

    function revokeSigner(address signer) external;

    function registerAndRevoke(address signerToRegister, address signerToRevoke, uint256 validityDays)
        external
        returns (uint256 validUntil);
}
