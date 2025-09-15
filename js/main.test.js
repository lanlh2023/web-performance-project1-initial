/**
 * Unit tests cho function showTopBar()
 * Test coverage: DOM manipulation, async behavior, CSS class changes
 */

// Import function cần test
const { showTopBar } = require('./main.js');

describe('showTopBar Function', () => {
  let countryBarElement;

  beforeAll(() => {
    // Setup DOM structure cho testing
    document.body.innerHTML = `
      <section class="country-bar hidden"></section>
    `;
  });

  beforeEach(() => {
    // Reset DOM state trước mỗi test
    countryBarElement = document.querySelector('section.country-bar');
    if (countryBarElement) {
      countryBarElement.innerHTML = '';
      countryBarElement.classList.add('hidden');
    }
    
    // Clear all timers
    jest.clearAllTimers();
  });

  afterEach(() => {
    // Cleanup sau mỗi test
    jest.clearAllTimers();
  });

  describe('DOM Element Selection', () => {
    test('should find the country-bar element', () => {
      expect(countryBarElement).toBeTruthy();
      expect(countryBarElement.tagName).toBe('SECTION');
      expect(countryBarElement.classList.contains('country-bar')).toBe(true);
    });
  });

  describe('Initial State', () => {
    test('should have hidden class initially', () => {
      expect(countryBarElement.classList.contains('hidden')).toBe(true);
    });

    test('should have empty innerHTML initially', () => {
      expect(countryBarElement.innerHTML).toBe('');
    });
  });

  describe('Async Behavior', () => {
    beforeEach(() => {
      // Sử dụng fake timers để test async behavior
      jest.useFakeTimers();
    });

    afterEach(() => {
      jest.useRealTimers();
    });

    test('should execute setTimeout with 1000ms delay', () => {
      const setTimeoutSpy = jest.spyOn(global, 'setTimeout');
      
      showTopBar();
      
      expect(setTimeoutSpy).toHaveBeenCalledTimes(1);
      expect(setTimeoutSpy).toHaveBeenCalledWith(expect.any(Function), 1000);
      
      setTimeoutSpy.mockRestore();
    });

    test('should not update DOM immediately after function call', () => {
      showTopBar();
      
      // DOM should not be updated immediately
      expect(countryBarElement.innerHTML).toBe('');
      expect(countryBarElement.classList.contains('hidden')).toBe(true);
    });

    test('should update DOM after 1000ms delay', () => {
      showTopBar();
      
      // Fast-forward time by 1000ms
      jest.advanceTimersByTime(1000);
      
      // DOM should be updated after timeout
      expect(countryBarElement.innerHTML).toBe('<p>Orders to <b>France</b> are subject to <b>20%</b> VAT</p>');
      expect(countryBarElement.classList.contains('hidden')).toBe(false);
    });

    test('should not update DOM before timeout completes', () => {
      showTopBar();
      
      // Fast-forward time by 999ms (just before timeout)
      jest.advanceTimersByTime(999);
      
      // DOM should not be updated yet
      expect(countryBarElement.innerHTML).toBe('');
      expect(countryBarElement.classList.contains('hidden')).toBe(true);
    });
  });

  describe('Content Generation', () => {
    beforeEach(() => {
      jest.useFakeTimers();
    });

    afterEach(() => {
      jest.useRealTimers();
    });

    test('should generate correct HTML content with France and 20% VAT', () => {
      showTopBar();
      jest.advanceTimersByTime(1000);
      
      const expectedContent = '<p>Orders to <b>France</b> are subject to <b>20%</b> VAT</p>';
      expect(countryBarElement.innerHTML).toBe(expectedContent);
    });

    test('should contain correct country name', () => {
      showTopBar();
      jest.advanceTimersByTime(1000);
      
      expect(countryBarElement.innerHTML).toContain('France');
    });

    test('should contain correct VAT percentage', () => {
      showTopBar();
      jest.advanceTimersByTime(1000);
      
      expect(countryBarElement.innerHTML).toContain('20%');
    });

    test('should have proper HTML structure with bold tags', () => {
      showTopBar();
      jest.advanceTimersByTime(1000);
      
      const innerHTML = countryBarElement.innerHTML;
      expect(innerHTML).toContain('<b>France</b>');
      expect(innerHTML).toContain('<b>20%</b>');
      expect(innerHTML).toContain('<p>');
    });
  });

  describe('CSS Class Manipulation', () => {
    beforeEach(() => {
      jest.useFakeTimers();
    });

    afterEach(() => {
      jest.useRealTimers();
    });

    test('should remove hidden class after timeout', () => {
      showTopBar();
      jest.advanceTimersByTime(1000);
      
      expect(countryBarElement.classList.contains('hidden')).toBe(false);
    });

    test('should keep hidden class before timeout', () => {
      showTopBar();
      jest.advanceTimersByTime(500);
      
      expect(countryBarElement.classList.contains('hidden')).toBe(true);
    });

    test('should only remove hidden class, not add any other classes', () => {
      showTopBar();
      jest.advanceTimersByTime(1000);
      
      expect(countryBarElement.classList.length).toBe(1); // Only 'country-bar' class
      expect(countryBarElement.classList.contains('country-bar')).toBe(true);
      expect(countryBarElement.classList.contains('hidden')).toBe(false);
    });
  });

  describe('Multiple Function Calls', () => {
    beforeEach(() => {
      jest.useFakeTimers();
    });

    afterEach(() => {
      jest.useRealTimers();
    });

    test('should handle multiple calls correctly', () => {
      showTopBar();
      showTopBar();
      
      jest.advanceTimersByTime(1000);
      
      // Should still work correctly with multiple calls
      expect(countryBarElement.innerHTML).toBe('<p>Orders to <b>France</b> are subject to <b>20%</b> VAT</p>');
      expect(countryBarElement.classList.contains('hidden')).toBe(false);
    });

    test('should not interfere with previous calls', () => {
      showTopBar();
      jest.advanceTimersByTime(500);
      
      showTopBar(); // Second call
      jest.advanceTimersByTime(500);
      
      // First call should complete
      expect(countryBarElement.innerHTML).toBe('<p>Orders to <b>France</b> are subject to <b>20%</b> VAT</p>');
      expect(countryBarElement.classList.contains('hidden')).toBe(false);
    });
  });

  describe('Error Handling', () => {
    test('should handle missing DOM element gracefully', () => {
      // Remove the element
      const parent = countryBarElement.parentNode;
      parent.removeChild(countryBarElement);
      
      // Function should not throw error (now has null check)
      expect(() => {
        showTopBar();
      }).not.toThrow();
    });

    test('should handle null querySelector result gracefully', () => {
      // Mock querySelector to return null
      const originalQuerySelector = document.querySelector;
      document.querySelector = jest.fn().mockReturnValue(null);
      
      // Function should not throw error (now has null check)
      expect(() => {
        showTopBar();
      }).not.toThrow();
      
      // Restore original function
      document.querySelector = originalQuerySelector;
    });
  });

  describe('Performance Considerations', () => {
    beforeEach(() => {
      jest.useFakeTimers();
    });

    afterEach(() => {
      jest.useRealTimers();
    });

    test('should not block main thread', () => {
      const startTime = Date.now();
      showTopBar();
      const endTime = Date.now();
      
      // Function should return immediately
      expect(endTime - startTime).toBeLessThan(10);
    });

    test('should use single setTimeout call', () => {
      const setTimeoutSpy = jest.spyOn(global, 'setTimeout');
      
      showTopBar();
      
      expect(setTimeoutSpy).toHaveBeenCalledTimes(1);
      
      setTimeoutSpy.mockRestore();
    });
  });
});
