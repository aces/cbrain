# System architecture

```mermaid
%%{init: {"theme": "base", "flowchart": {"defaultRenderer": "elk", "nodeSpacing": 20, "rankSpacing": 20}}}%%
flowchart LR
  Users([Researchers & Web browsers])
  NH[NeuroHub Portal<br/>Alternative UI]
  subgraph Frontend[Frontend resources]
    BP[BrainPortal<br/>Rails frontend]
    DB[(Shared database & metadata)]
  end
  subgraph ExternalResources[External resources]
    direction TB
    subgraph DataProviders[Data providers]
      direction TB
      DP1[Data provider<br/>S3/HTTP/FTP, etc.]
      DP2[Data provider<br/>S3/HTTP/FTP, etc.]
      DP3[More...]
    end
    subgraph HPCResources[HPC resources]
      direction TB
      subgraph ResourceA[HPC resource A]
        BO1[Bourreau]
        Sched1[HPC scheduler<br/>SLURM/PBS/...]
        subgraph ComputePoolA[Compute nodes]
          Compute1[Compute node]
          Compute2[Compute node]
          ComputeMoreA[More...]
        end
        Scratch1[(Working directories<br/>Shared storage)]
      end
      subgraph ResourceB[HPC resource B]
        BO2[Bourreau]
        Sched2[HPC scheduler<br/>SLURM/PBS/...]
        subgraph ComputePoolB[Compute nodes]
          Compute3[Compute node]
          Compute4[Compute node]
          ComputeMoreB[More...]
        end
        Scratch2[(Working directories<br/>Shared storage)]
      end
    end
  end

  Users --> BP
  Users --> NH
  NH --> BP
  BP --> DB
  BP --> DataProviders
  BP -->|SSH/XML| BO1
  BP -->|SSH/XML| BO2
  BO1 --> DataProviders
  BO2 --> DataProviders
  BO1 --> DB
  BO2 --> DB
  BO1 --> Sched1 --> ComputePoolA
  BO2 --> Sched2 --> ComputePoolB
  BO1 --> Scratch1
  BO2 --> Scratch2
  ComputePoolA --> Scratch1
  ComputePoolB --> Scratch2
```

At a high level, researchers interact with BrainPortal (or the NeuroHub
portal) through a web browser. The arrows in the diagram show the primary
request flow; responses are implied by each call. BrainPortal orchestrates
access to data providers, persists metadata in the shared database, and
delegates execution requests to one or more Bourreau instances, typically
over SSH/XML. Each Bourreau runs on a specific HPC resource and connects
to the local scheduler to launch jobs on that resource's compute
nodes. Bourreaux manage working directories on shared storage, synchronize
job and file state back to the database for BrainPortal to display, and
fetch or stage data from multiple data providers as part of backend task
execution.
