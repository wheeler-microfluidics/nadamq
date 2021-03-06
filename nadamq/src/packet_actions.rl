#ifdef ARDUINO
#include <Arduino.h>
#endif  // #ifdef ARDUINO

%%{

machine packet_grammar;

action error {
#if !defined(AVR) && !defined(__arm__) && defined(VERBOSE_STATES)
  std::cout << "[error]: " << std::hex << static_cast<int>(*p) << std::dec
            << std::endl;
#endif  // #ifdef VERBOSE_STATES
#ifdef ARDUINO_DEBUG
  Serial.print("[error]: ");
  Serial.print(static_cast<int>(*p));
  Serial.println("");
#endif  // #ifdef ARDUINO_DEBUG
  parse_error_ = true;
}

action startflag_received {
#if !defined(AVR) && !defined(__arm__) && defined(VERBOSE_STATES)
  std::cout << "[startflag_received]" << std::endl;
#endif  // #ifdef VERBOSE_STATES
#ifdef ARDUINO_DEBUG
  Serial.println("[startflag_received]");
#endif  // #ifdef ARDUINO_DEBUG
  // We're starting to process a new packet, so reset completed status.
  message_completed_ = false;
}

action id_start {
#if !defined(AVR) && !defined(__arm__) && defined(VERBOSE_STATES)
  std::cout << "[id_start]" << std::endl;
#endif  // #ifdef VERBOSE_STATES
  /* Reset the interface unique packet identifier. */
  packet_->iuid_ = 0;
}

action id_octet_received {
#if !defined(AVR) && !defined(__arm__) && defined(VERBOSE_STATES)
  std::cout << "[id_octet_received]" << std::endl;
#endif  // #ifdef VERBOSE_STATES
  /* Shift previous contents of interface unique packet identifier 8-bits to
   * the left, and write incoming byte as next byte of identifier. */
  packet_->iuid_ = (packet_->iuid_ << 8) | *p;
}

action type_received {
#if !defined(AVR) && !defined(__arm__) && defined(VERBOSE_STATES)
  std::cout << "[type_received]: " << static_cast<int>(*p) << std::endl;
#endif  // #ifdef VERBOSE_STATES
  packet_->type(*p);
}

action payload_start {
#if !defined(AVR) && !defined(__arm__) && defined(VERBOSE_STATES)
  std::cout << "[payload_start] expected size: " << payload_bytes_expected_
            << std::endl;
  std::cout << "[payload_start]: " << static_cast<int>(*p) << std::endl;
#endif  // #ifdef VERBOSE_STATES
#ifdef ARDUINO_DEBUG
  Serial.println("[payload]");
#endif  // #ifdef ARDUINO_DEBUG
  /* Resize the payload buffer to fit the expected payload size. */
  // packet_->reallocate_buffer(payload_bytes_expected_);
  // Reset received-bytes counter.
  payload_bytes_received_ = 0;
  crc_ = crc_init();
  if (payload_bytes_expected_ == 0) {
    /* No payload, so we're done. */

    /* Do not advance character pointer, since the character is *not* part of
     * the payload. */
    fhold;

    /* Return from the payload processing task. */
    fret;
  }
}

action payload_byte_received {
#if !defined(AVR) && !defined(__arm__) && defined(VERBOSE_STATES)
  std::cout << "[payload_byte_received] byte: " << payload_bytes_received_
            << std::endl;
#endif  // #ifdef VERBOSE_STATES
#ifdef ARDUINO_DEBUG
  Serial.print("[b] [");
  Serial.print(static_cast<char>(*p));
  Serial.print("] byte: ");
  Serial.println(payload_bytes_received_);
#endif  // #ifdef ARDUINO_DEBUG
  /* We received another payload octet, so:
   *
   *   - Update CRC checksum.
   *   - Copy octet _(i.e. byte)_ to payload buffer of packet.
   *   - Increment received count.
   *   - Check if we've received all expected octets. */
  crc_ = update_crc(crc_, *p);
  packet_->payload_buffer_[payload_bytes_received_++] = *p;
  if (payload_bytes_received_ == payload_bytes_expected_) {
    /* We've received the expected number of payload octets. */
    fret;
  }
}

action payload_end {
#if !defined(AVR) && !defined(__arm__) && defined(VERBOSE_STATES)
  std::cout << "[payload_end] received: " << payload_bytes_received_ << "/"
            << payload_bytes_expected_ << std::endl;
#endif  // #ifdef VERBOSE_STATES
  crc_ = finalize_crc(crc_);
}

action length_start {
#if !defined(AVR) && !defined(__arm__) && defined(VERBOSE_STATES)
  std::cout << "[length_start]" << std::endl;
#endif  // #ifdef VERBOSE_STATES
  length_bytes_received_ = 0;
  payload_bytes_expected_ = 0;
}

action length_byte_received {
#if !defined(AVR) && !defined(__arm__) && defined(VERBOSE_STATES)
  std::cout << "[length_byte_received]: " << std::hex << static_cast<int>(0x00FFFF & *p) << std::endl;
#endif  // #ifdef VERBOSE_STATES
  payload_bytes_expected_ <<= 8;
  payload_bytes_expected_ += *p;
}

action length_received {
#if !defined(AVR) && !defined(__arm__) && VERBOSE_STATES
  std::cout << "[length_received]: " << payload_bytes_expected_ << std::endl;
#endif  // #ifdef VERBOSE_STATES
#ifdef ARDUINO_DEBUG
  Serial.print("[len]: ");
  Serial.print(static_cast<int>(payload_bytes_expected_));
  Serial.print("/");
  Serial.println(packet_->buffer_size_);
#endif  // #ifdef ARDUINO_DEBUG
  if (payload_bytes_expected_ > packet_->buffer_size_) {
#if !defined(AVR) && !defined(__arm__)
      std::cerr << "[ERROR]: expected length is too long for buffer.  "
                   "Buffer length is " << packet_->buffer_size_ << std::endl;
#endif  // #ifndef AVR
    parse_error_ = true;
  }
}

action crc_start {
#if !defined(AVR) && !defined(__arm__) && defined(VERBOSE_STATES)
  std::cout << "[crc_start]" << std::endl;
#endif  // #ifdef VERBOSE_STATES
  packet_->crc_ = 0;
}

action crc_byte_received {
#if !defined(AVR) && !defined(__arm__) && defined(VERBOSE_STATES)
  std::cout << "[crc_byte_received]: " << std::hex << static_cast<int>(0x00FFFF & *p) << std::endl;
#endif  // #ifdef VERBOSE_STATES
  packet_->crc_ <<= 8;
  packet_->crc_ += *p;
}

action crc_received {
#if !defined(AVR) && !defined(__arm__) && defined(VERBOSE_STATES)
  std::cout << "[crc_received]: "
            << "from packet: " << packet_->crc_ << ", computed: " << crc_
            << std::endl;
#endif  // #ifdef VERBOSE_STATES
  if (packet_->crc_ == crc_) {
    /* The CRC checksum computed based on payload contents matches the CRC
     * checksum included from the packet.  We assume the packet was
     * successfully received.
     *
     * TODO
     * ====
     *
     * The CRC checksum should be computed from _all bytes in the packet_, not
     * just the _payload_.  This will help to ensure that the identifier, type,
     * etc. are not corrupted during transmission. */
    message_completed_ = true;
    /* Update payload length, since we successfully parsed the packet. */
    packet_->payload_length_ = payload_bytes_received_;
  } else {
    /* Reset state of packet, since the parsing was not successful. */
    parse_error_ = true;
  }
}

action ack_received {
#if !defined(AVR) && !defined(__arm__) && defined(VERBOSE_STATES)
  std::cout << "[ack_received]" << std::endl;
#endif  // #ifdef VERBOSE_STATES
  message_completed_ = true;
}

action id_request_received {
  /* .. versionadded 0.13 */
#if !defined(AVR) && !defined(__arm__) && defined(VERBOSE_STATES)
  std::cout << "[id_request_received]" << std::endl;
#endif  // #ifdef VERBOSE_STATES
  message_completed_ = true;
}

action nack_received {
#if !defined(AVR) && !defined(__arm__) && defined(VERBOSE_STATES)
  std::cout << "[nack_received]" << std::endl;
#endif  // #ifdef VERBOSE_STATES
  message_completed_ = true;
  packet_->payload_length_ = payload_bytes_expected_;
}

action packet_err {
#if !defined(AVR) && !defined(__arm__) && defined(VERBOSE_STATES)
  std::cout << "[packet_err]" << std::endl;
#endif  // #ifdef VERBOSE_STATES
  parse_error_ = true;
}

include "packet.rl";

}%%

#include <stdio.h>
#include <string.h>
#include "PacketParser.h"

%% write data;

template <typename Packet>
inline void PacketParser<Packet>::reset() {
  /*
   * Attempt to parse a packet from a buffer with length `buffer_len`.
   *
   * If successful, return `true` and set:
   *
   *  - `packet.type_`
   *  - `packet.payload_buffer_`
   *  - `packet.payload_length_`
   *
   * __NB__ No data is copied from the input `buffer` to
   * `packet.payload_buffer_`.  Instead, `packet.payload_buffer_` is set to
   * the location in `bufffer` where the payload is found during parsing,
   * while `packet.payload_length_` is set to the length of the
   * payload.  This means that the pointer `packet.payload_buffer_` is only
   * valid as long as `buffer` is valid.
   *
   * If unsuccessful, return `false`.  In the case of an unsuccessful parse
   * attempt, the state of attributes the attributes of `packet` are
   * _undefined_.
   */
  packet_->reset();
  crc_ = 0;
  message_completed_ = false;
  parse_error_ = false;
  payload_bytes_received_ = 0;
  length_bytes_received_ = 0;

  %% write init;
}


template <typename Packet>
inline void PacketParser<Packet>::parse_byte(uint8_t *byte) {
  uint8_t dummy_byte;

  if (byte == NULL) {
    /* If no byte is available _(i.e., `NULL` byte pointer was provided)_, set
     * Ragel parser pointers to trigger end-of-file actions. */
    p = &dummy_byte;
    pe = p;
    eof = p;
  } else {
    p = byte;
    pe = p + 1;
  }

  %% write exec;

#ifdef ARDUINO_DEBUG
  Serial.print("[p] (");
  Serial.print(cs);
  Serial.print(") ");
  if (*byte > 20 && *byte < 128) {
    Serial.print("'");
    Serial.print(static_cast<char>(*byte));
    Serial.print("'");
  } else {
    Serial.print(static_cast<int>(*byte));
  }
  Serial.println("");
#endif  // #ifdef ARDUINO_DEBUG
}


template void PacketParser<FixedPacket>::reset();
template void PacketParser<FixedPacket>::parse_byte(uint8_t *);
