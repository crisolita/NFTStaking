// SPDX-License-Identifier: BSD-4-Clause
/*
 * ABDK Math Quad Smart Contract Library.  Copyright © 2019 by ABDK Consulting.
 * Author: Mikhail Vladimirov <mikhail.vladimirov@gmail.com>
 */
pragma solidity ^0.8.0;

/**
 * Smart contract library of mathematical functions operating with IEEE 754
 * quadruple-precision binary floating-point numbers (quadruple precision
 * numbers).  As long as quadruple precision numbers are 16-bytes long, they are
 * represented by bytes16 type.
 */
library ABDKMathQuad {
    /**
     * Convert unsigned 256-bit integer number into quadruple precision number.
     *
     * @param x unsigned 256-bit integer number
     * @return quadruple precision number
     */
    function fromUInt(uint256 x) internal pure returns (bytes16) {
        unchecked {
            if (x == 0) return bytes16(0);
            else {
                uint256 result = x;

                uint256 msb = mostSignificantBit(result);
                if (msb < 112) result <<= 112 - msb;
                else if (msb > 112) result >>= msb - 112;

                result = (result & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF) | ((16383 + msb) << 112);

                return bytes16(uint128(result));
            }
        }
    }

    /**
     * Convert quadruple precision number into unsigned 256-bit integer number
     * rounding towards zero.  Revert on underflow.  Note, that negative floating
     * point numbers in range (-1.0 .. 0.0) may be converted to unsigned integer
     * without error, because they are rounded to zero.
     *
     * @param x quadruple precision number
     * @return unsigned 256-bit integer number
     */
    function toUInt(bytes16 x) internal pure returns (uint256) {
        unchecked {
            uint256 exponent = (uint128(x) >> 112) & 0x7FFF;

            if (exponent < 16383) return 0; // Underflow

            require(uint128(x) < 0x80000000000000000000000000000000); // Negative

            require(exponent <= 16638); // Overflow
            uint256 result = (uint256(uint128(x)) & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF) |
                0x10000000000000000000000000000;

            if (exponent < 16495) result >>= 16495 - exponent;
            else if (exponent > 16495) result <<= exponent - 16495;

            return result;
        }
    }

    /**
     * Calculate x * y.  Special values behave in the following way:
     *
     * NaN * x = NaN for any x.
     * Infinity * x = Infinity for any finite positive x.
     * Infinity * x = -Infinity for any finite negative x.
     * -Infinity * x = -Infinity for any finite positive x.
     * -Infinity * x = Infinity for any finite negative x.
     * Infinity * 0 = NaN.
     * -Infinity * 0 = NaN.
     * Infinity * Infinity = Infinity.
     * Infinity * -Infinity = -Infinity.
     * -Infinity * Infinity = -Infinity.
     * -Infinity * -Infinity = Infinity.
     *
     * @param x quadruple precision number
     * @param y quadruple precision number
     * @return quadruple precision number
     */
    function mul(bytes16 x, bytes16 y) internal pure returns (bytes16) {
        unchecked {
            bytes16 POSITIVE_ZERO = 0x00000000000000000000000000000000;
            bytes16 NEGATIVE_ZERO = 0x80000000000000000000000000000000;
            bytes16 NaN = 0x7FFF8000000000000000000000000000;
            uint256 xExponent = (uint128(x) >> 112) & 0x7FFF;
            uint256 yExponent = (uint128(y) >> 112) & 0x7FFF;

            if (xExponent == 0x7FFF) {
                if (yExponent == 0x7FFF) {
                    if (x == y) return x ^ (y & 0x80000000000000000000000000000000);
                    else if (x ^ y == 0x80000000000000000000000000000000) return x | y;
                    else return NaN;
                } else {
                    if (y & 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF == 0) return NaN;
                    else return x ^ (y & 0x80000000000000000000000000000000);
                }
            } else if (yExponent == 0x7FFF) {
                if (x & 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF == 0) return NaN;
                else return y ^ (x & 0x80000000000000000000000000000000);
            } else {
                uint256 xSignifier = uint128(x) & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
                if (xExponent == 0) xExponent = 1;
                else xSignifier |= 0x10000000000000000000000000000;

                uint256 ySignifier = uint128(y) & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
                if (yExponent == 0) yExponent = 1;
                else ySignifier |= 0x10000000000000000000000000000;

                xSignifier *= ySignifier;
                if (xSignifier == 0)
                    return
                        (x ^ y) & 0x80000000000000000000000000000000 > 0
                            ? NEGATIVE_ZERO
                            : POSITIVE_ZERO;

                xExponent += yExponent;

                uint256 msb = xSignifier >=
                    0x200000000000000000000000000000000000000000000000000000000
                    ? 225
                    : xSignifier >= 0x100000000000000000000000000000000000000000000000000000000
                    ? 224
                    : mostSignificantBit(xSignifier);

                if (xExponent + msb < 16496) {
                    // Underflow
                    xExponent = 0;
                    xSignifier = 0;
                } else if (xExponent + msb < 16608) {
                    // Subnormal
                    if (xExponent < 16496) xSignifier >>= 16496 - xExponent;
                    else if (xExponent > 16496) xSignifier <<= xExponent - 16496;
                    xExponent = 0;
                } else if (xExponent + msb > 49373) {
                    xExponent = 0x7FFF;
                    xSignifier = 0;
                } else {
                    if (msb > 112) xSignifier >>= msb - 112;
                    else if (msb < 112) xSignifier <<= 112 - msb;

                    xSignifier &= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

                    xExponent = xExponent + msb - 16607;
                }

                return
                    bytes16(
                        uint128(
                            uint128((x ^ y) & 0x80000000000000000000000000000000) |
                                (xExponent << 112) |
                                xSignifier
                        )
                    );
            }
        }
    }

    /**
     * Calculate x / y.  Special values behave in the following way:
     *
     * NaN / x = NaN for any x.
     * x / NaN = NaN for any x.
     * Infinity / x = Infinity for any finite non-negative x.
     * Infinity / x = -Infinity for any finite negative x including -0.
     * -Infinity / x = -Infinity for any finite non-negative x.
     * -Infinity / x = Infinity for any finite negative x including -0.
     * x / Infinity = 0 for any finite non-negative x.
     * x / -Infinity = -0 for any finite non-negative x.
     * x / Infinity = -0 for any finite non-negative x including -0.
     * x / -Infinity = 0 for any finite non-negative x including -0.
     *
     * Infinity / Infinity = NaN.
     * Infinity / -Infinity = -NaN.
     * -Infinity / Infinity = -NaN.
     * -Infinity / -Infinity = NaN.
     *
     * Division by zero behaves in the following way:
     *
     * x / 0 = Infinity for any finite positive x.
     * x / -0 = -Infinity for any finite positive x.
     * x / 0 = -Infinity for any finite negative x.
     * x / -0 = Infinity for any finite negative x.
     * 0 / 0 = NaN.
     * 0 / -0 = NaN.
     * -0 / 0 = NaN.
     * -0 / -0 = NaN.
     *
     * @param x quadruple precision number
     * @param y quadruple precision number
     * @return quadruple precision number
     */
    function div(bytes16 x, bytes16 y) internal pure returns (bytes16) {
        unchecked {
            uint256 xExponent = (uint128(x) >> 112) & 0x7FFF;
            uint256 yExponent = (uint128(y) >> 112) & 0x7FFF;
            bytes16 POSITIVE_ZERO = 0x00000000000000000000000000000000;
            bytes16 NEGATIVE_ZERO = 0x80000000000000000000000000000000;
            bytes16 POSITIVE_INFINITY = 0x7FFF0000000000000000000000000000;
            bytes16 NaN = 0x7FFF8000000000000000000000000000;

            if (xExponent == 0x7FFF) {
                if (yExponent == 0x7FFF) return NaN;
                else return x ^ (y & 0x80000000000000000000000000000000);
            } else if (yExponent == 0x7FFF) {
                if (y & 0x0000FFFFFFFFFFFFFFFFFFFFFFFFFFFF != 0) return NaN;
                else return POSITIVE_ZERO | ((x ^ y) & 0x80000000000000000000000000000000);
            } else if (y & 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF == 0) {
                if (x & 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF == 0) return NaN;
                else return POSITIVE_INFINITY | ((x ^ y) & 0x80000000000000000000000000000000);
            } else {
                uint256 ySignifier = uint128(y) & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
                if (yExponent == 0) yExponent = 1;
                else ySignifier |= 0x10000000000000000000000000000;

                uint256 xSignifier = uint128(x) & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
                if (xExponent == 0) {
                    if (xSignifier != 0) {
                        uint shift = 226 - mostSignificantBit(xSignifier);

                        xSignifier <<= shift;

                        xExponent = 1;
                        yExponent += shift - 114;
                    }
                } else {
                    xSignifier = (xSignifier | 0x10000000000000000000000000000) << 114;
                }

                xSignifier = xSignifier / ySignifier;
                if (xSignifier == 0)
                    return
                        (x ^ y) & 0x80000000000000000000000000000000 > 0
                            ? NEGATIVE_ZERO
                            : POSITIVE_ZERO;

                assert(xSignifier >= 0x1000000000000000000000000000);

                uint256 msb = xSignifier >= 0x80000000000000000000000000000
                    ? mostSignificantBit(xSignifier)
                    : xSignifier >= 0x40000000000000000000000000000
                    ? 114
                    : xSignifier >= 0x20000000000000000000000000000
                    ? 113
                    : 112;

                if (xExponent + msb > yExponent + 16497) {
                    // Overflow
                    xExponent = 0x7FFF;
                    xSignifier = 0;
                } else if (xExponent + msb + 16380 < yExponent) {
                    // Underflow
                    xExponent = 0;
                    xSignifier = 0;
                } else if (xExponent + msb + 16268 < yExponent) {
                    // Subnormal
                    if (xExponent + 16380 > yExponent) xSignifier <<= xExponent + 16380 - yExponent;
                    else if (xExponent + 16380 < yExponent)
                        xSignifier >>= yExponent - xExponent - 16380;

                    xExponent = 0;
                } else {
                    // Normal
                    if (msb > 112) xSignifier >>= msb - 112;

                    xSignifier &= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

                    xExponent = xExponent + msb + 16269 - yExponent;
                }

                return
                    bytes16(
                        uint128(
                            uint128((x ^ y) & 0x80000000000000000000000000000000) |
                                (xExponent << 112) |
                                xSignifier
                        )
                    );
            }
        }
    }

    /**
     * Get index of the most significant non-zero bit in binary representation of
     * x.  Reverts if x is zero.
     *
     * @return index of the most significant non-zero bit in binary representation
     *         of x
     */
    function mostSignificantBit(uint256 x) private pure returns (uint256) {
        unchecked {
            require(x > 0);

            uint256 result = 0;

            if (x >= 0x100000000000000000000000000000000) {
                x >>= 128;
                result += 128;
            }
            if (x >= 0x10000000000000000) {
                x >>= 64;
                result += 64;
            }
            if (x >= 0x100000000) {
                x >>= 32;
                result += 32;
            }
            if (x >= 0x10000) {
                x >>= 16;
                result += 16;
            }
            if (x >= 0x100) {
                x >>= 8;
                result += 8;
            }
            if (x >= 0x10) {
                x >>= 4;
                result += 4;
            }
            if (x >= 0x4) {
                x >>= 2;
                result += 2;
            }
            if (x >= 0x2) result += 1; // No need to shift x anymore

            return result;
        }
    }
}