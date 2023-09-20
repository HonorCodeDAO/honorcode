pragma solidity >=0.6.0;

library SafeMath {

    function abs(int x) internal pure returns (int z) {
        if (x > 0) {
            z = x;
        } else {
            z = 0-x;
        }
    }

    function max(uint x, uint y) internal pure returns (uint z) {
        if (x > y) {
            z = x;
        } else {
            z = y;
        }
    }

    function min(uint x, uint y) internal pure returns (uint z) {
        if (x < y) {
            z = x;
        } else {
            z = y;
        }
    }

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }

    function addInt(int x, int y) internal pure returns (int z) {
        if (y >= 0) {
            require((z = x + y) >= x, 'ds-math-addint-overflow');
        }
        else {
            require((z = x + y) < x, 'ds-math-addint-overflow');
        }
    }

    function subInt(int x, int y) internal pure returns (int z) {
        if (y >= 0) {
            require((z = x - y) <= x, 'ds-math-subint-underflow');
        } else {
            require((z = x - y) > x, 'ds-math-subint-underflow');
        }
    }

    function mulInt(int x, int y) internal pure returns (int z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mulint-overflow');
    }

    // function cubeRoot(uint x, uint tol) internal pure returns (uint z) {
    //     if (x > 8) {
    //         uint start = 0;
    //         uint end = x;
    //         while (sub(end, start) > 2 * tol) {
    //             z = add(start, end) / 2;
    //             if (z * z > x || z * z * z > x) {
    //                 end = z;
    //             }
    //             else {
    //                 start = z;
    //             }
    //         }
    //     }
    //     else if (y != 0) { 
    //         z = 1;
    //     }
    // }

    function floorCbrt(uint256 n) internal pure returns (uint256) { unchecked {
        uint256 x = 0;
        for (uint256 y = 1 << 255; y > 0; y >>= 3) {
            x <<= 1;
            uint256 z = 3 * x * (x + 1) + 1;
            if (n / y >= z) {
                n -= y * z;
                x += 1;
            }
        }
        return x;
    }}


    function floorSqrt(uint256 n) internal pure returns (uint256) { unchecked {
        if (n > 0) {
            uint256 x = n / 2 + 1;
            uint256 y = (x + n / x) / 2;
            while (x > y) {
                x = y;
                y = (x + n / x) / 2;
            }
            return x;
        }
        return 0;
    }}


}