import Testing
import DRCCore

@Suite("DRC backend identity")
struct DRCBackendIdentityTests {
    @Test func knownBackendFamiliesAreStable() {
        #expect(DRCBackendIdentity(backendID: "native").implementationFamily == .layoutVerify)
        #expect(DRCBackendIdentity(backendID: "native-gds").implementationFamily == .layoutVerify)
        #expect(DRCBackendIdentity(backendID: "magic").implementationFamily == .magic)
        #expect(DRCBackendIdentity(backendID: "klayout").implementationFamily == .klayout)
    }

    @Test func sameBackendAndSameFamilyAreNotIndependent() {
        let native = DRCBackendIdentity(backendID: "native-gds")
        #expect(native.independenceFailureCode(comparedTo: native) == "same_backend_reference")
        #expect(
            native.independenceFailureCode(
                comparedTo: DRCBackendIdentity(backendID: "native")
            ) == "same_implementation_family_reference"
        )
    }

    @Test func unknownBackendIdentityCannotQualifyAsIndependent() {
        #expect(
            DRCBackendIdentity(backendID: "custom-a")
                .independenceFailureCode(comparedTo: DRCBackendIdentity(backendID: "custom-b"))
                == "reference_independence_unproven"
        )
    }

    @Test func explicitImplementationFamilyIsRetainedForInjectedBackends() {
        let identity = DRCBackendIdentity(
            backendID: "reference",
            implementationFamily: .klayout,
            executableDigest: "exe-sha",
            ruleProgramDigest: "program-sha"
        )
        #expect(identity.implementationFamily == .klayout)
        #expect(identity.executableDigest == "exe-sha")
        #expect(identity.ruleProgramDigest == "program-sha")
    }

    @Test func externalReferenceRequiresExecutableRuleAndTechnologyAttestation() {
        let native = DRCBackendIdentity(backendID: "native")
        let unattestedMagic = DRCBackendIdentity(
            backendID: "magic",
            implementationFamily: .magic,
            executableDigest: "exe-sha",
            ruleProgramDigest: "program-sha"
        )
        let attestedMagic = DRCBackendIdentity(
            backendID: "magic",
            implementationFamily: .magic,
            executableDigest: String(repeating: "1", count: 64),
            ruleProgramDigest: String(repeating: "2", count: 64),
            technologyDigest: String(repeating: "3", count: 64)
        )

        #expect(!unattestedMagic.isAttested)
        #expect(
            native.independenceFailureCode(comparedTo: unattestedMagic)
                == "reference_attestation_unproven"
        )
        #expect(attestedMagic.isAttested)
        #expect(native.independenceFailureCode(comparedTo: attestedMagic) == nil)
    }
}
