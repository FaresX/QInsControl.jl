```@meta
CurrentModule = QInsControl
```

# QInsControl

QInsControl is designed for instrument control and data acquiring. It talks to instruments through
NI-VISA, raw TCP/IP sockets, serial ports, the ISOBUS and the QIC protocol, and provides a friendly
GUI together with a flexible block/text script system to keep both convenience and universality.

## Features

- **Instrument control** — auto-detection of connected instruments, register-defined quantities
  (sweep / set / read) with units, optional values, timeouts and per-quantity help documents.
- **Data acquiring** — a drag-and-drop task tree running block or text scripts, with progress bars,
  pause / continue / interrupt, circuit recording and timestamped autosave.
- **Data reviewing** — a file browser for saved data, a tabbed data viewer with CSV export and a
  batch formatter for replaying / exporting data.
- **Plotting** — GLMakie-powered plots with configurable data selection, real-time updating and
  user-defined data processing functions.
- **Multi-language UI** (English / 中文), fully editable themes, styles, fonts and wallpapers.
- **Remote mode** — two QInsControl instances can communicate with each other, so one can act as a
  monitor for the instruments connected to another one.

## Requirements

- Julia ≥ 1.10
- NI-VISA — only needed for VISA instruments (GPIB, USBTMC, VXI-11, ...). Raw TCP/IP socket and
  serial-port instruments work without VISA.

## Install

From the Julia package manager:

```
julia> ]
(@v1.10) pkg> add https://github.com/FaresX/QInsControl.jl.git
```

Or download a ready-to-run executable from the
[releases page](https://github.com/FaresX/QInsControl.jl/releases) for a quicker taste.

## Usage

```julia
using QInsControl
QInsControl.start()
```

## Addresses

| Instrument                | Address format                                       | Example                                  |
|:--------------------------|:-----------------------------------------------------|:-----------------------------------------|
| VISA (GPIB, USBTMC, ...)  | standard VISA resource name                          | `GPIB0::5::INSTR`                        |
| TCP/IP socket             | `TCPSOCKET::ip::port`                                | `TCPSOCKET::127.0.0.1::8080`             |
| Serial port               | `SERIAL::port`                                       | `SERIAL::COM1`                           |
| ISOBUS instrument         | `bus address::ISOBUS::sub address`                   | `ASRL1::INSTR::ISOBUS::1`                |
| QIC (remote QInsControl)  | `server address::QIC::instrument address`            | `TCPSOCKET::127.0.0.1::6060::QIC::SERIAL::COM1` |
| Virtual instrument        | `VirtualAddress` (no hardware needed, for testing)   | `VirtualAddress`                         |

With the QIC protocol one QInsControl (the server) is connected to the real instruments while
another one (the client) adds the server as if it were a local instrument, so the client can
control and log the instruments connected to the server.
