Mox.defmock(Avrora.HTTPClientMock, for: Avrora.HTTPClient)
Mox.defmock(Avrora.Storage.FileMock, for: Avrora.Storage)
Mox.defmock(Avrora.Storage.MemoryMock, for: [Avrora.Storage, Avrora.Storage.Transient])
Mox.defmock(Avrora.Storage.RegistryMock, for: Avrora.Storage)
