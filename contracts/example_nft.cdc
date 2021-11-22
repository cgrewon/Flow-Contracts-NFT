import NonFungibleToken from 0xfb7fb8b56a762069

pub contract ProvenancedTest1: NonFungibleToken {
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, name: String,ipfsLink: String)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    pub var totalSupply: UInt64

    pub resource interface Public {
        pub let id: UInt64
        pub let metadata: Metadata
    }

    //you can extend these fields if you need
    pub struct Metadata {
        pub let name: String
        pub let ipfsLink: String

        init(name: String,ipfsLink: String) {
            self.name=name
            //Stored in the ipfs
            self.ipfsLink=ipfsLink
        }
    }

   pub resource NFT: NonFungibleToken.INFT, Public {
        pub let id: UInt64
        pub let metadata: Metadata
        init(initID: UInt64,metadata: Metadata) {
            self.id = initID
            self.metadata=metadata
        }
    }

    pub resource interface ProvenancedTest1CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowArt(id: UInt64): &ProvenancedTest1.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow ProvenancedTest1 reference: The ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: ProvenancedTest1CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @ProvenancedTest1.NFT

            let id: UInt64 = token.id

            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }


        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return &self.ownedNFTs[id] as &NonFungibleToken.NFT
        }

        pub fun borrowArt(id: UInt64): &ProvenancedTest1.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
                return ref as! &ProvenancedTest1.NFT
            } else {
                return nil
            }
        }

        destroy() {
            destroy self.ownedNFTs
        }

        init () {
            self.ownedNFTs <- {}
        }
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub struct NftData {
        pub let metadata: ProvenancedTest1.Metadata
        pub let id: UInt64
        init(metadata: ProvenancedTest1.Metadata, id: UInt64) {
            self.metadata= metadata
            self.id=id
        }
    }

    pub fun getNft(address:Address) : [NftData] {
        var artData: [NftData] = []
        let account=getAccount(address)

        if let artCollection= account.getCapability(self.CollectionPublicPath).borrow<&{ProvenancedTest1.ProvenancedTest1CollectionPublic}>()  {
            for id in artCollection.getIDs() {
                var art=artCollection.borrowArt(id: id)
                artData.append(NftData(metadata: art!.metadata,id: id))
            }
        }
        return artData
    }

    pub fun checkInitialized(address:Address) : Bool {
        
        let account=getAccount(address)

        if let artCollection= account.getCapability(self.CollectionPublicPath).borrow<&{ProvenancedTest1.ProvenancedTest1CollectionPublic}>()  {
            return true
        }
        return false
    }

	pub resource NFTMinter {
		pub fun mintNFT(
		recipient: &{NonFungibleToken.CollectionPublic},
		name: String,
        ipfsLink: String) {
            emit Minted(id: ProvenancedTest1.totalSupply, name: name, ipfsLink: ipfsLink)

			recipient.deposit(token: <-create ProvenancedTest1.NFT(
			    initID: ProvenancedTest1.totalSupply,
			    metadata: Metadata(
                    name: name,
                    ipfsLink:ipfsLink,
                )))

            ProvenancedTest1.totalSupply = ProvenancedTest1.totalSupply + (1 as UInt64)
		}
	}

    init() {
        self.CollectionStoragePath = /storage/ProvenancedTest1Collection
        self.CollectionPublicPath = /public/ProvenancedTest1Collection
        self.MinterStoragePath = /storage/ProvenancedTest1Minter

        self.totalSupply = 0

        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        let collection <- ProvenancedTest1.createEmptyCollection()
        
        self.account.save(<-collection, to: ProvenancedTest1.CollectionStoragePath)

        self.account.link<&ProvenancedTest1.Collection{NonFungibleToken.CollectionPublic, ProvenancedTest1.ProvenancedTest1CollectionPublic}>(ProvenancedTest1.CollectionPublicPath, target: ProvenancedTest1.CollectionStoragePath)

        emit ContractInitialized()
    }
}